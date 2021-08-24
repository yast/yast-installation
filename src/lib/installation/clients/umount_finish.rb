# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
# Copyright (c) 2013-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "installation/finish_client"
require "installation/unmounter"
require "storage"
require "y2storage"
require "shellwords"

module Installation
  module Clients
    # Finish client to unmount all mounts to the target
    class UmountFinishClient < FinishClient
      include Yast::Logger

      # Constructor
      def initialize
        textdomain "installation"
        Yast.import "Installation"
        Yast.import "Hotplug"
        Yast.import "String"
        Yast.import "FileUtils"
        @running_standalone = false
      end

      # This can be used when invoking this file directly with
      # ruby ./umount_finish.rb
      #
      def run_standalone
        @running_standalone = true
        Installation.destdir = "/mnt" if Installation.destdir == "/"
        write
      end

      protected

      def title
        # progress step title
        _("Unmounting all mounted devices...")
      end

      def modes
        [:installation, :live_installation, :update, :autoinst]
      end

      # Perform the final actions in the target system
      def write
        log.info("Starting umount_finish.rb")

        close_scr_on_target
        remove_target_etc_mtab
        set_btrfs_defaults_as_ro # No write access to the target after this!
        umount_target_mounts

        log.info("umount_finish.rb done")
        true
      end

      # Unmount all mounts to the target typically /mnt.
      #
      # This uses an Installation::Unmounter object which reads /proc/mounts.
      # Relying on y2storage would be risky here since other processes like
      # snapper or libzypp may have mounted filesystems without y2storage
      # knowing about it.
      #
      def umount_target_mounts
        dump_file("/proc/partitions")
        dump_file("/proc/mounts")
        unmounter = ::Installation::Unmounter.new(Installation.destdir)
        log.info("Paths to unmount: #{unmounter.unmount_paths}")
        return if unmounter.mounts.empty?

        begin
          unmounter.execute
        rescue Cheetah::ExecutionFailed => e # Typically permissions problem
          log.error(e.message)
        end
        unmounter.clear
        unmounter.read_mounts_file("/proc/mounts")
        unmount_summary(unmounter.unmount_paths)
      end

      # Write a summary of the unmount operations to the log.
      def unmount_summary(leftover_paths)
        if (leftover_paths.empty?)
          log.info("All unmounts successful")
        else
          log.warn("Leftover paths that could not be unmounted: #{leftover_paths}")
          dump_file("/proc/mounts")
          leftover_paths.each { |p| log_running_processes(p) }
        end
      end

      # Dump a file in human-readable form to the log.
      # Do not add the y2log header to each line so it can be easily used.
      def dump_file(filename)
        content = File.read(filename)
        log.info("\n\n#{filename}:\n\n#{content}\n")
      end

      def remove_target_etc_mtab
        # symlink points to /proc, keep it (bnc#665437)
        if !FileUtils.IsLink("/etc/mtab")
          # remove [Installation::destdir]/etc/mtab which was faked for %post
          # scripts in inst_rpmcopy
          SCR.Execute(path(".target.remove"), "/etc/mtab")

          # hotfix: recreating /etc/mtab as symlink (bnc#725166)
          SCR.Execute(path(".target.bash"), "ln -s /proc/self/mounts /etc/mtab")
        end
      end

      def close_scr_on_target
        WFM.SCRClose(Installation.scr_handle)
      end

      # For btrfs filesystems that should be read-only, set the root subvolume
      # to read-only and change the /etc/fstab entry accordingly.
      #
      # Since we had to install RPMs to the target, we could not set it to
      # read-only right away; but now we can, and we have to.
      #
      # This must be done as long as the target root is still mounted
      # (because the btrfs command requires that), but after the last write
      # access to it (because it will be read only afterwards).
      def set_btrfs_defaults_as_ro
        return if @running_standalone # Can't get storage lock without root privleges

        devicegraph = Y2Storage::StorageManager.instance.staging

        ro_btrfs_filesystems = devicegraph.filesystems.select do |fs|
          new_filesystem?(fs) && ro_btrfs_filesystem?(fs)
        end

        ro_btrfs_filesystems.each { |f| default_subvolume_as_ro(f) }
      end

      # [String] Name used by btrfs tools to name the filesystem tree.
      BTRFS_FS_TREE = "(FS_TREE)".freeze

      # Set the "read-only" property for the root subvolume.
      # This has to be done as long as the target root filesystem is still
      # mounted.
      #
      # @param fs [Y2Storage::Filesystems::Btrfs] Btrfs filesystem to set read-only property on.
      def default_subvolume_as_ro(fs)
        output = Yast::Execute.on_target(
          "btrfs", "subvolume", "get-default", fs.mount_point.path, stdout: :capture
        )
        default_subvolume = output.strip.split.last
        # no btrfs_default_subvolume and no snapshots
        default_subvolume = "" if default_subvolume == BTRFS_FS_TREE

        subvolume_path = fs.btrfs_subvolume_mount_point(default_subvolume)

        log.info("Setting root subvol read-only property on #{subvolume_path}")
        Yast::Execute.on_target("btrfs", "property", "set", subvolume_path, "ro", "true")
      end

      # run "fuser" to get the details about open files
      #
      # @param mount_point [String]
      def log_running_processes(mount_point)
        fuser =
          begin
            # (the details are printed on STDERR, redirect it)
            `LC_ALL=C fuser -v -m #{Shellwords.escape(mount_point)} 2>&1`
          rescue => e
            "fuser failed: #{e}"
          end
        log.warn("Running processes using #{mount_point}: #{fuser}")
      end

      # Check whether the given filesystem is going to be created
      #
      # @param filesystem [Y2Storage::Filesystems::Base]
      # @return [Boolean]
      def new_filesystem?(filesystem)
        !filesystem.exists_in_probed?
      end

      # Check whether the given filesystem is read-only BTRFS
      #
      # @param filesystem [Y2Storage::Filesystems::Base]
      # @return [Boolean]
      def ro_btrfs_filesystem?(filesystem)
        filesystem.is?(:btrfs) && filesystem.mount_point && filesystem.mount_options.include?("ro")
      end
    end
  end
end

if $0 == __FILE__    # Called direcly as standalone command? (not via rspec or require)
  puts("Running UmountFinishClient standalone")
  Installation::Clients::UmountFinishClient.new.run_standalone
  puts("UmountFinishClient done")
end

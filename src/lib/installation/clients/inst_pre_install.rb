# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

require "installation/ssh_importer"
require "y2storage"

module Yast
  class InstPreInstallClient < Client
    include Yast::Logger

    def main
      Yast.import "Directory"
      Yast.import "SystemFilesCopy"
      Yast.import "ProductControl"
      Yast.import "String"

      # --> Variables

      # all devices that can be used as a source of data
      @useful_devices = []

      # *******************************************************************************
      # --> main()

      Initialize()

      each_mounted_device do |device, mount_point|
        read_users(device, mount_point) if can_read_users?
        read_ssh_info(device, mount_point)
      end

      # The ssh_import proposal doesn't make sense if there is no
      # configuration to import from.
      if ::Installation::SshImporter.instance.configurations.empty?
        ProductControl.DisableSubProposal("inst_initial", "ssh_import")
      end

      # free the memory
      @useful_devices = nil

      # at least some return
      :auto
    end

    def Initialize
      Builtins.y2milestone("Evaluating all current partitions")

      # limit the number of the searched disks to 8 of each kind in order to avoid neverending
      # mounting of all partitions (fate#305873, bnc#468922)
      # FIXME: copy-pasted from partitioner, just different number of disks and added /dev/dasd
      restrict_disk_names = lambda do |disks|
        helper = lambda do |s|
          count = 0
          disks = disks.select do |dist|
            next true unless dist.start_with?(s)
            (count += 1) <= 8
          end

          nil
        end

        helper.call("/dev/sd")
        helper.call("/dev/hd")
        helper.call("/dev/cciss/")
        helper.call("/dev/dasd")

        Builtins.y2milestone("restrict_disk_names: ret %1", disks)
        deep_copy(disks)
      end

      probed = Y2Storage::StorageManager.instance.probed
      device_names = probed.disk_devices.map(&:name)
      device_names = restrict_disk_names.call(device_names)
      Builtins.foreach(device_names) do |device_name|
        device = Y2Storage::BlkDevice.find_by_name(probed, device_name)
        filesystems = device.descendants.select { |i| i.is?(:blk_filesystem) }
        filesystems.each do |filesystem|
          device = filesystem.blk_devices.first
          if !filesystem.type.root_ok?
            log.info(
              "Skipping device #{device.name}, "\
              "#{filesystem.type} is not a root filesystem"
            )
            next
          end
          @useful_devices << device.name
        end
      end
      # Duplicates can happen, e.g. if there are PVs for the same LVM VG in
      # several disks
      @useful_devices.uniq!

      Builtins.y2milestone("Possible devices: %1", @useful_devices)

      nil
    end

  protected

    # Checks whether it's possible to read the existing users databases
    def can_read_users?
      @can_read_users ||= begin
        require_users_database
        defined? Users::UsersDatabase
      end
    end

    # Requires users_database if possible, not failing otherwise
    def require_users_database
      require "users/users_database"
    rescue LoadError
      log.error "UsersDatabase not found. YaST2-users is missing, old or broken."
    end

    # Stores the users database (/etc/passwd and friends) of a given filesystem
    # in UsersDatabase.all, so it can be used during the users import step
    #
    # @param device [String] device name of the filesystem
    # @param mount_point [String] path where the filesystem is mounted
    def read_users(device, mount_point)
      log.info "Reading users information from #{device}"
      Users::UsersDatabase.import(mount_point)
    end

    # Stores the SSH configuration of a given partition in the SSH importer
    # @see CopyFilesFinishClient and SshImportProposalClient
    #
    # @param device [String] device name of the filesystem
    # @param mount_point [String] path where the filesystem is mounted
    def read_ssh_info(device, mount_point)
      log.info "Reading SSH information from #{device}"
      ::Installation::SshImporter.instance.add_config(mount_point, device)
    end

    def each_mounted_device(&block)
      mnt_tmpdir = "#{Directory.tmpdir}/tmp_mnt_for_check"
      mnt_tmpdir = SystemFilesCopy.CreateDirectoryIfMissing(mnt_tmpdir)

      # CreateDirectory failed
      if mnt_tmpdir.nil?
        log.error "Error creating temporary directory"
        return
      end

      @useful_devices.each do |device|
        log.info "Mounting #{device} to #{mnt_tmpdir}"
        already_mounted = "grep '[\\t ]#{mnt_tmpdir}[\\t ]' /proc/mounts"
        am = SCR.Execute(path(".target.bash_output"), already_mounted)
        if am["exit"] == 0 && !am["stdout"].to_s.empty?
          log.warning "#{mnt_tmpdir} is already mounted, trying to umount..."
          log.error("Cannot umount #{mnt_tmpdir}") unless SCR.Execute(path(".target.umount"), mnt_tmpdir)
        end
        # mounting read-only
        if !SCR.Execute(path(".target.mount"), [device, mnt_tmpdir], "-o ro,noatime")
          log.error "Mounting falied!"
          next
        end

        block.call(device, mnt_tmpdir)

        # bnc #427879
        exec = SCR.Execute(
          path(".target.bash_output"),
          "fuser -v '#{String.Quote(mnt_tmpdir)}' 2>&1"
        )
        log.error("Processes in #{mnt_tmpdir}: #{exec}") unless exec["stdout"].to_s.empty?
        # umounting
        log.info "Umounting #{device}"
        log.error("Umount failed!") unless SCR.Execute(path(".target.umount"), mnt_tmpdir)
      end
    end
  end
end

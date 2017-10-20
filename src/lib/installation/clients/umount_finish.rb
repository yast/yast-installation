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

# File:
#  umount_finish.rb
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>

module Yast
  class UmountFinishClient < Client
    include Yast::Logger

    EFIVARS_PATH = "/sys/firmware/efi/efivars".freeze
    USB_PATH = "/proc/bus/usb".freeze

    def main
      Yast.import "Pkg"

      textdomain "installation"

      Yast.import "Installation"
      Yast.import "Hotplug"
      Yast.import "Vendor"
      Yast.import "String"
      Yast.import "Internet"
      Yast.import "FileUtils"
      Yast.import "Mode"
      Yast.import "ProductFeatures"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting umount_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Unmounting all mounted devices..."
          ),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # Release all sources, they might be still mounted
        Pkg.SourceReleaseAll

        # save all sources and finish target
        # bnc #398315
        Pkg.SourceSaveAll
        Pkg.TargetFinish

        Builtins.y2milestone(
          "/proc/mounts:\n%1",
          WFM.Read(path(".local.string"), "/proc/mounts")
        )
        Builtins.y2milestone(
          "/proc/partitions:\n%1",
          WFM.Read(path(".local.string"), "/proc/partitions")
        )

        # get mounts at and in the target from /proc/mounts - do not use
        # Storage here since Storage does not know whether other processes,
        # e.g. snapper, mounted filesystems in the target

        umount_list = []
        SCR.Read(path(".proc.mounts")).each do |entry|
          mountpoint = entry["file"]
          if mountpoint.start_with?(Installation.destdir)
            umount_list << mountpoint[Installation.destdir.length, mountpoint.length]
          end
        end
        umount_list.sort!
        log.info("umount_list:#{umount_list}")

        # symlink points to /proc, keep it (bnc#665437)
        if !FileUtils.IsLink("/etc/mtab")
          # remove [Installation::destdir]/etc/mtab which was faked for %post
          # scripts in inst_rpmcopy
          SCR.Execute(path(".target.remove"), "/etc/mtab")

          # hotfix: recreating /etc/mtab as symlink (bnc#725166)
          SCR.Execute(path(".target.bash"), "ln -s /proc/self/mounts /etc/mtab")
        end

        # Stop SCR on target
        WFM.SCRClose(Installation.scr_handle)

        # first, umount everthing mounted *in* the target.
        # /proc/bus/usb
        # /proc

        @umount_these = ["/proc", "/sys", "/dev", "/run"]
        if Hotplug.haveUSB
          @umount_these.unshift(USB_PATH)
        end

        if File.exist?(EFIVARS_PATH) #exists in both inst-sys and target or in neither
          @umount_these.unshift(EFIVARS_PATH)
        end

        Builtins.foreach(@umount_these) do |umount_dir|
          umount_this = Builtins.sformat(
            "%1%2",
            Installation.destdir,
            umount_dir
          )
          Builtins.y2milestone("Umounting: %1", umount_this)
          umount_result = Convert.to_boolean(
            WFM.Execute(path(".local.umount"), umount_this)
          )
          if umount_result != true
            # bnc #395034
            # Don't remount them read-only!
            if Builtins.contains(
              ["/proc", "/sys", "/dev", USB_PATH, EFIVARS_PATH],
              umount_dir
            )
              Builtins.y2warning("Umount failed, trying lazy umount...")
              cmd = Builtins.sformat(
                "sync; umount -l -f '%1';",
                String.Quote(umount_this)
              )
            else
              Builtins.y2warning(
                "Umount failed, trying to remount read only..."
              )
              cmd = Builtins.sformat(
                "sync; mount -o remount,noatime,ro '%1'; umount -l -f '%1';",
                String.Quote(umount_this)
              )
            end
            Builtins.y2milestone(
              "Cmd: '%1' Ret: %2",
              cmd,
              WFM.Execute(path(".local.bash_output"), cmd)
            )
          end
        end

        # BNC #692799: Preserve the randomness state before umounting
        preserve_randomness_state

        #
        # !!! NO WRITE OPERATIONS TO THE TARGET AFTER THIS POINT !!!
        #

        # This must be done as long as the target root is still mounted
        # (because the btrfs command requires that), but after the last write
        # access to it (because it will be read only afterwards).
        set_root_subvol_read_only

# storage-ng
# rubocop:disable Style/BlockComments
=begin

        @targetMap = Storage.GetTargetMap

        # first umount all file based crypto fs since they potentially
        # could mess up umounting of normale filesystems if the crypt
        # file is not on the root fs
        Builtins.y2milestone("umount list %1", umount_list)
        Builtins.foreach(
          Ops.get_list(@targetMap, ["/dev/loop", "partitions"], [])
        ) do |e|
          if Ops.greater_than(Builtins.size(Ops.get_string(e, "mount", "")), 0)
            Storage.Umount(Ops.get_string(e, "device", ""), true)
            umount_list = Builtins.filter(umount_list) do |m|
              m != Ops.get_string(e, "mount", "")
            end
            Builtins.y2milestone(
              "loop umount %1 new list %2",
              Ops.get_string(e, "mount", ""),
              umount_list
            )
          end
        end

=end

        # *** umount_list is lexically ordered !
        # now umount in reverse order (guarantees "/" as last umount)

        @umountLength = Builtins.size(umount_list)

        while Ops.greater_than(@umountLength, 0)
          @umountLength = Ops.subtract(@umountLength, 1)
          @tmp = Ops.add(
            Installation.destdir,
            Ops.get(umount_list, @umountLength, "")
          )

          Builtins.y2milestone(
            "umount target: %1, %2 more to go..",
            @tmp,
            @umountLength
          )

          @umount_status = Convert.to_boolean(
            WFM.Execute(path(".local.umount"), @tmp)
          )

          # bnc #395034
          # Don't remount them read-only!
          next if @umount_status

          if Builtins.contains(
            ["/proc", "/sys", "/dev", "/proc/bus/usb"],
            @tmp
          )
            Builtins.y2warning("Umount failed, trying lazy umount...")
            @cmd2 = Builtins.sformat(
              "sync; umount -l -f '%1';",
              String.Quote(@tmp)
            )
          else
            Builtins.y2warning(
              "Umount failed, trying to remount read only..."
            )
            @cmd2 = Builtins.sformat(
              "mount -o remount,ro,noatime '%1'; umount -l -f '%1';",
              String.Quote(@tmp)
            )
          end
          Builtins.y2milestone(
            "Cmd: '%1' Ret: %2",
            @cmd2,
            WFM.Execute(path(".local.bash_output"), @cmd2)
          )

        end

        # bugzilla #326478
        Builtins.y2milestone(
          "Currently mounted partitions: %1",
          WFM.Execute(path(".local.bash_output"), "mount")
        )

        @cmd = Builtins.sformat(
          "fuser -v '%1' 2>&1",
          String.Quote(Installation.destdir)
        )
        @cmd_run = Convert.to_map(WFM.Execute(path(".local.bash_output"), @cmd))

# storage-ng
=begin

        # must call .local.bash_output !
        @max_loop_dev = Storage.NumLoopDevices

        # disable loop device of crypto fs
        @unload_crypto = false

        while Ops.greater_than(@max_loop_dev, 0)
          @unload_crypto = true
          @exec_str = Builtins.sformat(
            "/sbin/losetup -d /dev/loop%1",
            Ops.subtract(@max_loop_dev, 1)
          )
          Builtins.y2milestone("loopdev: %1", @exec_str)
          WFM.Execute(path(".local.bash"), @exec_str)
          @max_loop_dev = Ops.subtract(@max_loop_dev, 1)
        end

        if @targetMap.any? { |_k, v| v["type"] == :CT_LVM }
          Builtins.y2milestone("shutting down LVM")
          WFM.Execute(path(".local.bash"), "/sbin/vgchange -a n")
        end

=end

      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("umount_finish finished")
      deep_copy(@ret)
    end

    # Calls a local command and returns if successful
    def LocalCommand(command)
      cmd = Convert.to_map(WFM.Execute(path(".local.bash_output"), command))
      Builtins.y2milestone("Command %1 returned: %2", command, cmd)

      return true if Ops.get_integer(cmd, "exit", -1) == 0

      if Ops.get_string(cmd, "stderr", "") != ""
        Builtins.y2error("Error: %1", Ops.get_string(cmd, "stderr", ""))
      end
      false
    end

    # Reads and returns the current poolsize from /proc.
    # Returns integer size as a string.
    def read_poolsize
      poolsize_path = "/proc/sys/kernel/random/poolsize"

      poolsize = Convert.to_string(
        WFM.Read(path(".local.string"), poolsize_path)
      )

      if poolsize.nil? || poolsize == ""
        Builtins.y2warning(
          "Cannot read poolsize from %1, using the default",
          poolsize_path
        )
        poolsize = "4096"
      else
        poolsize = Builtins.regexpsub(poolsize, "^([[:digit:]]+).*", "\\1")
      end

      Builtins.y2milestone("Using random/poolsize: '%1'", poolsize)
      poolsize
    end

    # Preserves the current randomness state, BNC #692799
    def preserve_randomness_state
      if Mode.update
        Builtins.y2milestone("Not saving current random seed - in update mode")
        return
      end

      Builtins.y2milestone("Saving the current randomness state...")

      service_bin = "/usr/sbin/haveged"
      random_path = "/dev/urandom"
      store_to = Builtins.sformat(
        "%1/var/lib/misc/random-seed",
        Installation.destdir
      )

      @ret = true

      # Copy the current state of random number generator to the installed system
      if LocalCommand(
        Builtins.sformat(
          "dd if='%1' bs=%2 count=1 of='%3'",
          String.Quote(random_path),
          read_poolsize,
          String.Quote(store_to)
        )
      )
        Builtins.y2milestone(
          "State of %1 has been successfully copied to %2",
          random_path,
          store_to
        )
      else
        Builtins.y2milestone(
          "Cannot store %1 state to %2",
          random_path,
          store_to
        )
        @ret = false
      end

      # stop the random number generator service
      Builtins.y2milestone("Stopping %1 service", service_bin)
      LocalCommand(Builtins.sformat("killproc -TERM %1", service_bin))

      nil
    end

    # Set the root subvolume to read-only and change the /etc/fstab entry
    # accordingly
    #
    def set_root_subvol_read_only
      return unless root_subvol_read_only_configured?
      log.info("Setting root subvolume to read-only")
      set_fstab_root_subvol_read_only
      set_root_subvol_property_read_only
    end

    # Check the product configuration (control.xml) if the root subvolume
    # should be set to read-only.
    #
    def root_subvol_read_only_configured?
      ProductFeatures.GetBooleanFeature("partitioning", "root_subvolume_read_only")
    end

    # Change /etc/fstab on the target to mount the root subvolume read-only.
    #
    def set_fstab_root_subvol_read_only
      cmd = "sed -i -e '/ \\/ btrfs/s/defaults/ro/' /etc/fstab"
      log.info("Setting root subvol to read-only in /etc/fstab: \"#{cmd}\"")
      SCR.Execute(path(".target.bash"), cmd)
    end

    # Set the "read-only" property for the root subvolume.
    # This has to be done as long as the target root filesystem is still
    # mounted.
    #
    def set_root_subvol_property_read_only
      cmd = "btrfs property set /.snapshots/1/snapshot ro true"
      log.info("Setting root subvol read-only property: \"#{cmd}\"")
      SCR.Execute(path(".target.bash"), cmd)
    end
  end
end

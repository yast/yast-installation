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

module Yast
  class InstPreInstallClient < Client
    include Yast::Logger

    def main
      Yast.import "Storage"
      Yast.import "FileSystems"
      Yast.import "FileUtils"
      Yast.import "Directory"
      Yast.import "SystemFilesCopy"
      Yast.import "ProductFeatures"
      Yast.import "ProductControl"
      Yast.import "InstData"
      Yast.import "String"
      Yast.import "Linuxrc"
      Yast.import "InstFunctions"

      # --> Variables

      # all partitions that can be used as a source of data
      @useful_partitions = []

      # *******************************************************************************
      # --> main()

      Initialize()

      if SystemFilesCopy.GetUseControlFileDef
        Builtins.y2milestone("Using copy_to_system from control file")

        # FATE #305019: configure the files to copy from a previous installation
        # -> configuration moved to control file
        @copy_items = Convert.convert(
          ProductFeatures.GetFeature("globals", "copy_to_system"),
          from: "any",
          to:   "list <map>"
        )
        @copy_items ||= []

        @copy_items.each do |one_copy_item|
          item_id = one_copy_item["id"]

          if InstFunctions.feature_ignored?(item_id)
            Builtins.y2milestone("Feature #{item_id} skipped on user request")
            next
          end

          copy_to_dir     = one_copy_item.fetch("copy_to_dir", Directory.vardir)
          mandatory_files = one_copy_item.fetch("mandatory_files", [])
          optional_files  = one_copy_item.fetch("optional_files", [])

          FindAndCopyNewestFiles(copy_to_dir, mandatory_files, optional_files)
        end
      end

      if SystemFilesCopy.GetCopySystemFiles != []
        Builtins.y2milestone("Using additional copy_to_system")

        Builtins.foreach(SystemFilesCopy.GetCopySystemFiles) do |one_copy_item|
          copy_to_dir = Builtins.tostring(
            Ops.get_string(one_copy_item, "copy_to_dir", Directory.vardir)
          )
          mandatory_files = Ops.get_list(one_copy_item, "mandatory_files", [])
          optional_files = Ops.get_list(one_copy_item, "optional_files", [])
          FindAndCopyNewestFiles(copy_to_dir, mandatory_files, optional_files)
        end
      end

      each_mounted_partition do |device, mount_point|
        read_users(device, mount_point) if can_read_users?
        read_ssh_info(device, mount_point)
      end

      # The ssh_import proposal doesn't make sense if there is no
      # configuration to import from.
      if ::Installation::SshImporter.instance.configurations.empty?
        ProductControl.DisableSubProposal("inst_initial", "ssh_import")
      end

      # free the memory
      @useful_partitions = nil

      # at least some return
      :auto
    end

    def FindTheBestFiles(files_found)
      files_found = deep_copy(files_found)
      ret = {}
      max = 0

      # going through all partitions
      Builtins.foreach(files_found) do |partition_name, files_on_it|
        counter = 0
        filetimes = 0
        Builtins.foreach(files_on_it) do |_filename, filetime|
          filetimes = Ops.add(filetimes, filetime)
          counter = Ops.add(counter, 1)
        end
        # if there were some files on in
        if Ops.greater_than(counter, 0)
          # average filetime (if more files were there)
          filetimes = Ops.divide(filetimes, counter)

          # the current time is bigger (newer file) then the maximum found
          if Ops.greater_than(filetimes, max)
            max = filetimes
            ret = {}
            Ops.set(ret, partition_name, files_on_it)
          end
        end
      end

      deep_copy(ret)
    end

    def FindAndCopyNewestFiles(copy_to, wanted_files, optional_files)
      wanted_files = deep_copy(wanted_files)
      optional_files = deep_copy(optional_files)
      Builtins.y2milestone("Searching for files: %1", wanted_files)

      files_found_on_partitions = {}

      each_mounted_partition do |device, mnt_tmpdir|
        files_found = true
        one_partition_files_found = {}
        Builtins.foreach(wanted_files) do |wanted_file|
          filename_to_seek = Ops.add(mnt_tmpdir, wanted_file)
          if !FileUtils.Exists(filename_to_seek)
            files_found = false
            next
          end
          if FileUtils.IsLink(filename_to_seek)
            files_found = false
            next
          end
          file_attribs = Convert.to_map(
            SCR.Read(path(".target.lstat"), filename_to_seek)
          )
          if file_attribs.nil? || file_attribs == {}
            files_found = false
            next
          end
          # checking for the acces-time
          file_time = Ops.get_integer(file_attribs, "atime")
          if file_time.nil? || file_time == 0
            files_found = false
            next
          end
          # doesn't make sense to copy files with zero size
          file_size = Ops.get_integer(file_attribs, "atime")
          if file_size.nil? || file_size == 0
            files_found = false
            next
          end
          Ops.set(one_partition_files_found, wanted_file, file_time)
        end
        next unless files_found
        Ops.set(files_found_on_partitions, device, one_partition_files_found)
      end

      Builtins.y2milestone("Files found: %1", files_found_on_partitions)

      ic_winner = {}

      # nothing found
      if Builtins.size(files_found_on_partitions) == 0
        Builtins.y2milestone("No such files found")
        # only one (easy)
      elsif Builtins.size(files_found_on_partitions) == 1
        ic_winner = deep_copy(files_found_on_partitions)
        # more than one (getting the best ones)
      else
        ic_winner = FindTheBestFiles(files_found_on_partitions)
      end
      files_found_on_partitions = nil

      Builtins.y2milestone("Selected files: %1", ic_winner)

      # should be only one entry
      Builtins.foreach(ic_winner) do |partition, files|
        SystemFilesCopy.CopyFilesToTemp(
          partition,
          Convert.convert(
            Builtins.union(Builtins.maplist(files) do |filename, _filetime|
              filename
            end, optional_files),
            from: "list",
            to:   "list <string>"
          ),
          copy_to
        )
      end

      nil
    end

    def Initialize
      Builtins.y2milestone("Evaluating all current partitions")

      # limit the number of the searched disks to 8 of each kind in order to avoid neverending
      # mounting of all partitions (fate#305873, bnc#468922)
      # FIXME: copy-pasted from partitioner, just different number of disks and added /dev/dasd
      restrict_disk_names = lambda do |disks|
        disks = deep_copy(disks)
        helper = lambda do |s|
          count = 0
          disks = Builtins.filter(disks) do |dist|
            next true if Builtins.search(dist, s) != 0
            count = Ops.add(count, 1)
            Ops.less_or_equal(count, 8)
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

      target_map = Storage.GetTargetMap
      counter = -1
      device_names = Builtins.maplist(target_map) do |device_name, _device_descr|
        device_name
      end
      device_names = restrict_disk_names.call(device_names)
      Builtins.foreach(device_names) do |device_name|
        device_descr = Ops.get(target_map, device_name, {})
        partitions = Ops.get_list(device_descr, "partitions", [])
        filesystem = nil
        devicename = nil
        Builtins.foreach(partitions) do |partition|
          filesystem = Ops.get_symbol(
            partition,
            "used_fs",
            Ops.get(partition, "detected_fs")
          )
          devicename = Ops.get_string(partition, "device")
          if filesystem.nil?
            Builtins.y2milestone(
              "Skipping partition %1, no FS detected",
              devicename
            )
            next
          end
          if !Builtins.contains(FileSystems.possible_root_fs, filesystem)
            Builtins.y2milestone(
              "Skipping partition %1, %2 is not a root filesystem",
              devicename,
              filesystem
            )
            next
          end
          # adding the partition into the list of possible ones
          counter = Ops.add(counter, 1)
          Ops.set(
            @useful_partitions,
            counter,
            "device" => Ops.get(partition, "device"), "fs" => filesystem
          )
        end
      end

      Builtins.y2milestone("Possible partitions: %1", @useful_partitions)

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

    def each_mounted_partition(&block)
      mnt_tmpdir = "#{Directory.tmpdir}/tmp_mnt_for_check"
      mnt_tmpdir = SystemFilesCopy.CreateDirectoryIfMissing(mnt_tmpdir)

      # CreateDirectory failed
      if mnt_tmpdir.nil?
        log.error "Error creating temporary directory"
        return
      end

      @useful_partitions.each do |partition|
        partition_device = partition["device"] || ""
        log.info "Mounting #{partition_device} to #{mnt_tmpdir}"
        already_mounted = Builtins.sformat(
          "grep '[\\t ]%1[\\t ]' /proc/mounts",
          mnt_tmpdir
        )
        am = SCR.Execute(path(".target.bash_output"), already_mounted)
        if am["exit"] == 0 && !am["stdout"].to_s.empty?
          log.warning "#{mnt_tmpdir} is already mounted, trying to umount..."
          log.error("Cannot umount #{mnt_tmpdir}") unless SCR.Execute(path(".target.umount"), mnt_tmpdir)
        end
        # mounting read-only
        if !SCR.Execute(path(".target.mount"), [partition_device, mnt_tmpdir], "-o ro,noatime")
          log.error "Mounting falied!"
          next
        end

        block.call(partition_device, mnt_tmpdir)

        # bnc #427879
        exec = SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("fuser -v '%1' 2>&1", String.Quote(mnt_tmpdir))
        )
        log.error("Processes in #{mnt_tmpdir}: #{exec}") unless exec["stdout"].to_s.empty?
        # umounting
        log.info "Umounting #{partition_device}"
        log.error("Umount failed!") unless SCR.Execute(path(".target.umount"), mnt_tmpdir)
      end
    end
  end
end

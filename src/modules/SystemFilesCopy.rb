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

# File:	modules/SystemFilesCopy.ycp
# Package:	Installation
# Summary:	Functionality for copying files from another systems
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# Functionality for copying files from any not-mounted systems
# to inst-sys and from inst-sys to just-installed system.
require "yast"

module Yast
  class SystemFilesCopyClass < Module
    def main
      textdomain "installation"

      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "String"
      Yast.import "Installation"
      Yast.import "ProductFeatures"
      Yast.import "Stage"
      Yast.import "InstData"

      # --> Variables

      #
      # **Structure:**
      #
      #     [
      #          [ archive_name, copy_to ],
      #          [ "/tmp/archive_001.tgz", "/etc" ],
      #      ]
      @copy_files_to_installed_system = []

      @already_initialized = false

      @inst_sys_tmp_directory = nil

      @tmp_mount_directory = nil

      # max tries when creating a temporary mount-directory
      @counter_max = 10

      @tmp_archive_counter = 0
    end

    # Checks whether the directory exists and creates it if it is missing
    # If the path exists but it is not a directory, it tries to create another
    # directory and returns its name. 'nil' is returned when everythig fails.
    #
    # @param string mnt_tmpdir
    # #return string mnt_tmpdir (maybe changed)
    def CreateDirectoryIfMissing(create_directory)
      # path already exists
      if FileUtils.Exists(create_directory)
        # exists as a directory
        if FileUtils.IsDirectory(create_directory)
          Builtins.y2milestone("Directory %1 already exists", create_directory)
          return create_directory 
          # exists but it's not a directory
        else
          Builtins.y2warning("Path %1 is not a directory", create_directory)
          new_dir = nil

          while new_dir == nil && Ops.greater_than(@counter_max, 0)
            @counter_max = Ops.subtract(@counter_max, 1)
            create_directory = Ops.add(create_directory, "x")
            new_dir = CreateDirectoryIfMissing(create_directory)
          end

          return new_dir
        end 

        # path doesn't exist
      else
        SCR.Execute(path(".target.mkdir"), create_directory)
        # created successfully
        if FileUtils.Exists(create_directory)
          Builtins.y2milestone("Directory %1 created", create_directory)
          return create_directory 
          # cannot create
        else
          Builtins.y2error("Cannot create path %1", create_directory)
          return nil
        end
      end
    end

    # Sets and creates a temporary directory for files to lay
    # in inst-sys until they're copied to the installed system.
    # Sets and creates a temporary directory that is used for
    # mounting partitions when copying files from them.
    def Initialize
      return true if @already_initialized

      @inst_sys_tmp_directory = CreateDirectoryIfMissing(
        "/tmp/tmp_dir_for_SystemFilesCopy_files"
      )
      @tmp_mount_directory = CreateDirectoryIfMissing(
        "/tmp/tmp_dir_for_SystemFilesCopy_mount"
      )

      if @inst_sys_tmp_directory == nil || @tmp_mount_directory == nil
        Builtins.y2error("Cannot create one of needed directories")
        return false
      end

      # everything is fine
      @already_initialized = true
      true
    end

    # Mounts the partition and proceeds the copying files from that partition
    # to the inst-sys.
    #
    #
    # **Structure:**
    #
    #     partiton  == "/dev/sdb4"
    #
    # **Structure:**
    #
    #     filenames == [ "/etc/123", "/etc/456" ]
    #
    # **Structure:**
    #
    #     copy_to   == "/root/" (where to copy it to the installed system)
    def CopyFilesToTemp(partition, filenames, copy_to)
      filenames = deep_copy(filenames)
      if !Initialize()
        Builtins.y2error("Cannot initialize!")
        return false
      end

      # creating full archive name (path)
      @tmp_archive_counter = Ops.add(@tmp_archive_counter, 1)
      archive_name = Builtins.sformat(
        "%1/_inst_archive_%2.tgz",
        @inst_sys_tmp_directory,
        @tmp_archive_counter
      )

      Builtins.y2milestone(
        "Copying from '%1' files %2 to '%3'. Files will appear in '%4'",
        partition,
        filenames,
        archive_name,
        copy_to
      )

      Builtins.y2milestone("Mounting %1 to %2", partition, @tmp_mount_directory)
      if !Convert.to_boolean(
          SCR.Execute(
            path(".target.mount"),
            [partition, @tmp_mount_directory],
            "-o ro,noatime"
          )
        )
        Builtins.y2error("Mounting failed!")
        return false
      end

      ret = true
      archive_files = ""
      Builtins.foreach(filenames) do |filename|
        # removing the leading slash
        if Builtins.substring(filename, 0, 1) == "/"
          filename = Builtins.substring(filename, 1)
        end
        archive_files = Ops.add(
          Ops.add(Ops.add(archive_files, " '"), String.Quote(filename)),
          "'"
        )
      end

      # archive files were already quoted
      command = Builtins.sformat(
        # 'ignore failed read' is for optional files
        # but needs to be entered after the archive name
        # bugzilla #326055
        "cd '%1'; tar --recursion -zcvf '%2' --ignore-failed-read %3",
        @tmp_mount_directory,
        String.Quote(archive_name),
        archive_files
      )
      cmd_run = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), command)
      )
      if Ops.get_integer(cmd_run, "exit") != 0
        Builtins.y2error(
          "Problem during archivation: %1, command >%2<",
          cmd_run,
          command
        )
        ret = false
      else
        Builtins.y2milestone("Archived: %1", cmd_run)
      end

      Builtins.y2milestone("Umounting %1", partition)
      if !Convert.to_boolean(
          SCR.Execute(path(".target.umount"), @tmp_mount_directory)
        )
        Builtins.y2warning("Umounting failed!")
      end

      # add a new entry into the list of archives
      @copy_files_to_installed_system = Builtins.add(
        @copy_files_to_installed_system,
        [archive_name, copy_to]
      )

      ret
    end

    # Proceeds the copying of all files in inst-sys (that were copied from
    # another partition before) to the directory.
    #
    # @param [String] extract_to_dir (Installation::destdir for initial stage of installation)
    def CopyFilesToSystem(extract_to_dir)
      if !@already_initialized
        Builtins.y2error("CopyFilesToTemp() needs to be called first...")
        return false
      end

      ret = true

      # this should run before the SCR root is changed
      Builtins.foreach(@copy_files_to_installed_system) do |archive_to_extract|
        archive_name = Ops.get(archive_to_extract, 0)
        where_to_extract = Ops.get(archive_to_extract, 1)
        if archive_name == nil || where_to_extract == nil
          Builtins.y2error(
            "Something is wrong with the archive: %1",
            archive_to_extract
          )
          ret = false
        end
        where_to_extract = Builtins.sformat(
          "%1%2",
          extract_to_dir,
          where_to_extract
        )
        command = Builtins.sformat(
          "mkdir -p '%1'; cd '%1'; tar --preserve-permissions --preserve-order -xvzf '%2'",
          String.Quote(where_to_extract),
          String.Quote(archive_name)
        )
        cmd_run = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), command)
        )
        if Ops.get_integer(cmd_run, "exit") != 0
          Builtins.y2error(
            "Problem during extracting an archive: %1, command >%2<",
            cmd_run,
            command
          )
          ret = false
        else
          Builtins.y2milestone(
            "Extracted: %1 into %2",
            cmd_run,
            where_to_extract
          )
        end
      end

      true
    end

    # internal functions for SaveInstSysContent -->

    def AdjustDirectoryPath(directory_path)
      dir_path_list = Builtins.splitstring(directory_path, "/")

      dir_path_list = Builtins.filter(dir_path_list) { |one_dir| one_dir != "" }

      directory_path = Builtins.mergestring(dir_path_list, "/")
      directory_path = Builtins.sformat("/%1/", directory_path)

      directory_path
    end

    def CopyFilesFromDirToDir(dir_from, dir_to)
      cmd = Builtins.sformat(
        "mkdir -p '%2' && cp -ar '%1.' '%2'",
        String.Quote(dir_from),
        String.Quote(dir_to)
      )
      cmd_run = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))

      if Ops.get_integer(cmd_run, "exit", -1) != 0
        Builtins.y2error("Command %1 failed %2", cmd, cmd_run)
        return false
      else
        Builtins.y2milestone("Command >%1< succeeded", cmd)
        return true
      end
    end

    # <-- internal functions for SaveInstSysContent

    # Function reads <globals><save_instsys_content /></globals>
    # from control file and copies all content from inst-sys to
    # the just installed system.
    #
    # This function needs to be called in the inst-sys (first stage)
    # just before the disk is unmounted.
    #
    # FATE #301937
    #
    #
    # **Structure:**
    #
    #
    #      <globals>
    #          <save_instsys_content config:type="list">
    #              <save_instsys_item>
    #                  <instsys_directory>/root/</instsys_directory>
    #                  <system_directory>/root/inst-sys/</system_directory>
    #              </save_instsys_item>
    #          </save_instsys_content>
    #      </globals>
    def SaveInstSysContent
      if !Stage.initial
        Builtins.y2error(
          "This function can be called in the initial stage only!"
        )
        return false
      end

      globals_features = ProductFeatures.GetSection("globals")

      if globals_features == nil
        Builtins.y2warning("No <globals> defined")
        return false
      elsif Ops.get_list(globals_features, "save_instsys_content", []) == []
        Builtins.y2milestone("No items to copy from inst-sys")
        return true
      end

      save_content = Convert.convert(
        Ops.get(globals_features, "save_instsys_content"),
        from: "any",
        to:   "list <map <string, string>>"
      )
      if save_content == nil
        Builtins.y2error(
          "Cannot save inst-sys content: %1",
          Ops.get(globals_features, "save_instsys_content")
        )
        return false
      end

      Builtins.y2milestone("Save inst-sys content: %1", save_content)
      Builtins.foreach(save_content) do |copy_item|
        if Ops.get(copy_item, "instsys_directory", "") == ""
          Builtins.y2error("Error: %1 is not defined", "instsys_directory")
          next
        elsif Ops.get(copy_item, "system_directory", "") == ""
          Builtins.y2error("Error: %1 is not defined", "system_directory")
          next
        end
        dir_from = Builtins.sformat(
          "/%1/",
          Ops.get(copy_item, "instsys_directory", "")
        )
        dir_to = Builtins.sformat(
          "/%1/%2/",
          Installation.destdir,
          Ops.get(copy_item, "system_directory", "")
        )
        dir_from = AdjustDirectoryPath(dir_from)
        dir_to = AdjustDirectoryPath(dir_to)
        if dir_from == dir_to
          Builtins.y2error(
            "Dir 'from (%1)' and 'to (%2)' mustn't be the same",
            dir_from,
            dir_to
          )
          next
        end
        # search ("/a", "/b") -> nil
        # search ("/a/b", "/a") -> 0
        # search ("/a/b/", "/b/") -> 2
        position_str_in_str = Builtins.search(dir_to, dir_from)
        if position_str_in_str != nil && position_str_in_str == 0
          Builtins.y2error(
            "Cannot copy a directory content to itself (%1 -> %2)",
            dir_from,
            dir_to
          )
          next
        end
        CopyFilesFromDirToDir(dir_from, dir_to)
      end

      true
    end

    # FATE #305019: configure the files to copy from a previous installation
    # -->

    # Sets whether copy_files from control file should be used
    #
    # @return [Boolean] whether to use them
    # @see #SetUseControlFileDef
    def GetUseControlFileDef
      InstData.copy_files_use_control_file == true
    end

    # Sets whether to use copy_files from control file
    #
    # @param boolean whether to use them
    # @see #GetUseControlFileDef
    def SetUseControlFileDef(new_value)
      if new_value == nil
        Builtins.y2error("Wrong value: %1", new_value)
        return
      end

      InstData.copy_files_use_control_file = new_value
      Builtins.y2milestone(
        "Using copy_to_system from control file set to: %1",
        new_value
      )

      nil
    end

    # Returns list of copy_files definitions
    # @see SetCopySystemFiles for more info
    def GetCopySystemFiles
      deep_copy(InstData.additional_copy_files)
    end

    # Sets new rules which files will be copied during installation.
    #
    # @see FATE #305019: configure the files to copy from a previous installation
    # @param list <map> of new definitions
    #
    #
    # **Structure:**
    #
    #
    #         [
    #             "copy_to_dir" : (string) "system_directory_to_copy_to",
    #             "mandatory_files" : (list <string>) [ list of mandatory files ],
    #             "optional_files" : (list <string>) [ list of optional files ],
    #         ]
    #
    # @example
    #    SetCopySystemFiles ([
    #        $["copy_to_dir":"/root/backup", "mandatory_files":["/etc/passwd", "/etc/shadow"]]
    #        $["copy_to_dir":"/root/backup", "mandatory_files":["/etc/ssh/ssh_host_dsa_key"], "optional_files":["/etc/ssh/ssh_host_rsa_key.pub"]]
    #    ])
    def SetCopySystemFiles(new_copy_files)
      new_copy_files = deep_copy(new_copy_files)
      InstData.additional_copy_files = []

      use_item = true

      Builtins.foreach(new_copy_files) do |one_copy_item|
        copy_to_dir = Builtins.tostring(
          Ops.get_string(one_copy_item, "copy_to_dir", Directory.vardir)
        )
        if copy_to_dir == nil || copy_to_dir == ""
          Builtins.y2error("(string) 'copy_to_dir' must be defined")
          use_item = false
        end
        mandatory_files = Ops.get_list(one_copy_item, "mandatory_files", [])
        if mandatory_files == nil || mandatory_files == []
          Builtins.y2error("(list <string>) 'mandatory_files' must be defined")
          use_item = false
        end
        optional_files = Ops.get_list(one_copy_item, "optional_files", [])
        if optional_files == nil
          Builtins.y2error("(list <string>) 'optional_files' wrong definition")
          use_item = false
        end
        if use_item
          InstData.additional_copy_files = Builtins.add(
            InstData.additional_copy_files,
            one_copy_item
          )
        end
      end

      nil
    end

    publish function: :CreateDirectoryIfMissing, type: "string (string)"
    publish function: :CopyFilesToTemp, type: "boolean (string, list <string>, string)"
    publish function: :CopyFilesToSystem, type: "boolean (string)"
    publish function: :SaveInstSysContent, type: "boolean ()"
    publish function: :GetUseControlFileDef, type: "boolean ()"
    publish function: :SetUseControlFileDef, type: "void (boolean)"
    publish function: :GetCopySystemFiles, type: "list <map> ()"
    publish function: :SetCopySystemFiles, type: "void (list <map>)"
  end

  SystemFilesCopy = SystemFilesCopyClass.new
  SystemFilesCopy.main
end

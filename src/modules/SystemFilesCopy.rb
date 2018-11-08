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

      @already_initialized = false

      # max tries when creating a temporary mount-directory
      @counter_max = 10
    end

    # Checks whether the directory exists and creates it if it is missing
    # If the path exists but it is not a directory, it tries to create another
    # directory and returns its name. 'nil' is returned when everythig fails.
    #
    # @param create_directory [String] directory to create
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

          while new_dir.nil? && @counter_max > 0
            @counter_max -= 1
            create_directory += "x"
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

      # everything is fine
      @already_initialized = true
      true
    end

    # internal functions for SaveInstSysContent -->

    def AdjustDirectoryPath(directory_path)
      dir_path_list = Builtins.splitstring(directory_path, "/")

      dir_path_list = Builtins.filter(dir_path_list) { |one_dir| one_dir != "" }

      directory_path = Builtins.mergestring(dir_path_list, "/")
      directory_path = "/#{directory_path}/"

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

      if globals_features.nil?
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
      if save_content.nil?
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
        dir_from = "/#{Ops.get(copy_item, "instsys_directory", "")}/"
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
        if !position_str_in_str.nil? && position_str_in_str == 0
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

    publish function: :CreateDirectoryIfMissing, type: "string (string)"
    publish function: :SaveInstSysContent, type: "boolean ()"
  end

  SystemFilesCopy = SystemFilesCopyClass.new
  SystemFilesCopy.main
end

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

# File:  clients/inst_license.ycp
# Package:  Installation
# Summary:  Generic License File
# Authors:  Anas Nashif <nashif@suse.de>
#    Jiri Srain <jsrain@suse.cz>
#    Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class InstLicenseClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Directory"
      Yast.import "GetInstArgs"
      Yast.import "Stage"
      Yast.import "ProductLicense"
      Yast.import "Mode"
      Yast.import "ProductFeatures"
      Yast.import "Wizard"
      Yast.import "Report"

      # all the arguments
      @argmap = GetInstArgs.argmap

      # Action if license is not accepted
      # abort|continue|halt
      # halt is the default
      # bugzilla #252132
      @action = Ops.get_string(@argmap, "action", "halt")

      # Do not halt the machine in case of declining the license
      # just abort
      # bugzilla #330730
      @action = "abort" if Mode.live_installation

      @test_mode = false

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        Builtins.y2milestone("Args: %1", WFM.Args)

        @test_mode = true if WFM.Args(0) == "test"
      end

      Wizard.CreateDialog if @test_mode

      @ask_ret = nil

      if Stage.initial
        @ask_ret = ProductLicense.AskFirstStageLicenseAgreement(0, @action)
      else
        # #304865: Enhance YaST Modules to cooperate better handling the product licenses
        @directory = Ops.get_string(@argmap, "directory", "")

        # FATE #306295: More licenses in one dialog
        @directories = Ops.get_list(@argmap, "directories", [])

        # Priority 0: More directories
        if !@directories.nil? && @directories != []
          Builtins.y2milestone("Using directories: %1", @directories)
          # Priority 1: Script args
        elsif !@directory.nil? && @directory != ""
          Builtins.y2milestone("Using directory: %1", @directory)
          @directories = [@directory]
          # Priority 2: Fallback - Control file
        else
          @directory = ProductFeatures.GetStringFeature(
            "globals",
            "base_product_license_directory"
          )

          # control file
          if !@directory.nil? && @directory != ""
            Builtins.y2milestone(
              "Using directory (from control file): %1",
              @directory
            )
            # fallback - hard-coded
          else
            @directory = "/usr/share/licenses/product/base/"
            Builtins.y2warning(
              "No 'base_product_license_directory' set, using %1",
              @directory
            )
          end

          @directories = [@directory]
        end

        if !@directories.nil?
          @tmp_directories = Builtins.maplist(@directories) do |one_directory|
            Ops.add(Directory.custom_workflow_dir, one_directory)
          end
          @directories = deep_copy(@tmp_directories)
          Builtins.y2milestone(
            "License directories after additional modifications: %1",
            @directories
          )
        end

        if @directories.nil? || @directories == []
          # Error message
          Report.Error(_("Internal error: Missing license to show"))
          Builtins.y2error("Nothing to do")
          @ask_ret = :auto
        elsif Ops.greater_than(Builtins.size(@directories), 1)
          @ask_ret = ProductLicense.AskInstalledLicensesAgreement(
            @directories,
            @action
          )
        else
          @ask_ret = ProductLicense.AskInstalledLicenseAgreement(
            Ops.get(@directories, 0, ""),
            @action
          )
        end
      end

      Wizard.CloseDialog if @test_mode

      case @ask_ret
      when nil, :auto
        :auto
      when :abort, :back
        @ask_ret
      when :halt
        UI.CloseDialog
        # License has been aborted
        # bugzilla #282958
        SCR.Execute(path(".target.bash"), "/sbin/halt -f -n -p") if @test_mode != true
        :abort
      when :next, :accepted
        :next
      else
        Builtins.y2error("Unknown return: %1", @ask_ret)
        :next
      end
    end
  end
end

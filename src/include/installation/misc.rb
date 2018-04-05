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
#      include/installation/misc.ycp
#
# Module:
#      System installation
#
# Summary:
#      Miscelaneous functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  module InstallationMiscInclude
    def initialize_installation_misc(_include_target)
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Label"
      Yast.import "FileUtils"
      Yast.import "Linuxrc"
      Yast.import "InstData"
      Yast.import "HTML"
      Yast.import "Storage"

      @modules_to_enable_with_AC_on = nil
    end

    # Function appends blacklisted modules to the /etc/modprobe.d/50-blacklist.conf
    # file.
    #
    # More information in bugzilla #221815 and #485980
    def AdjustModprobeBlacklist
      # check whether we need to run it
      brokenmodules = Linuxrc.InstallInf("BrokenModules")
      if brokenmodules == "" || brokenmodules.nil?
        Builtins.y2milestone("No BrokenModules in install.inf, skipping...")
        return
      end

      # comma-separated list of modules
      blacklisted_modules = Builtins.splitstring(brokenmodules, ", ")

      # run before SCR switch
      blacklist_file = Ops.add(
        Installation.destdir,
        "/etc/modprobe.d/50-blacklist.conf"
      )

      # read the content
      content = ""
      if FileUtils.Exists(blacklist_file)
        content = Convert.to_string(
          SCR.Read(path(".target.string"), blacklist_file)
        )
        if content.nil?
          Builtins.y2error("Cannot read %1 file", blacklist_file)
          content = ""
        end
      else
        Builtins.y2warning(
          "File %1 does not exist, installation will create new one",
          blacklist_file
        )
      end

      # creating new entries with comment
      blacklist_file_added = "# Note: Entries added during installation/update (Bug 221815)\n"
      Builtins.foreach(blacklisted_modules) do |blacklisted_module|
        blacklist_file_added = Ops.add(
          blacklist_file_added,
          Builtins.sformat("blacklist %1\n", blacklisted_module)
        )
      end

      # newline if the file is not empty
      content = Ops.add(
        Ops.add(content, content != "" ? "\n\n" : ""),
        blacklist_file_added
      )

      Builtins.y2milestone(
        "Blacklisting modules: %1 in %2",
        blacklisted_modules,
        blacklist_file
      )
      if !SCR.Write(path(".target.string"), blacklist_file, content)
        Builtins.y2error("Cannot write into %1 file", blacklist_file)
      else
        Builtins.y2milestone(
          "Changes into file %1 were written successfully",
          blacklist_file
        )
      end

      nil
    end

    def InjectFile(filename)
      command = "/bin/cp #{filename} #{Installation.destdir}#{filename}"
      Builtins.y2milestone("InjectFile: <%1>", filename)
      Builtins.y2debug("Inject command: #{command}")
      WFM.Execute(path(".local.bash"), command)
      nil

      # this just needs too much memory
      # byteblock copy_buffer = WFM::Read (.local.byte, filename);
      # return SCR::Write (.target.byte, filename, copy_buffer);
    end

    def UpdateWizardSteps
      wizard_mode = Mode.mode
      Builtins.y2milestone("Switching Steps to %1 ", wizard_mode)

      stage_mode = [
        { "stage" => "initial", "mode" => wizard_mode },
        { "stage" => "continue", "mode" => wizard_mode }
      ]
      Builtins.y2milestone("Updating wizard steps: %1", stage_mode)

      ProductControl.UpdateWizardSteps(stage_mode)

      nil
    end

    # Some client calls have to be called even if using AC
    def EnableRequiredModules
      # Lazy init
      if @modules_to_enable_with_AC_on.nil?
        feature = ProductFeatures.GetFeature(
          "globals",
          "autoconfiguration_enabled_modules"
        )

        @modules_to_enable_with_AC_on = if feature == "" || feature.nil? || feature == []
          []
        else
          Convert.convert(
            feature,
            from: "any",
            to:   "list <string>"
          )
        end

        Builtins.y2milestone(
          "Steps to enable with AC in use: %1",
          @modules_to_enable_with_AC_on
        )
      end

      if !@modules_to_enable_with_AC_on.nil?
        Builtins.foreach(@modules_to_enable_with_AC_on) do |one_module|
          ProductControl.EnableModule(one_module)
        end
      end

      nil
    end

    def AdjustStepsAccordingToInstallationSettings
      if Installation.add_on_selected == true ||
          !Linuxrc.InstallInf("addon").nil?
        ProductControl.EnableModule("add-on")
      else
        ProductControl.DisableModule("add-on")
      end

      if Installation.productsources_selected == true
        ProductControl.EnableModule("productsources")
      else
        ProductControl.DisableModule("productsources")
      end

      Builtins.y2milestone(
        "Disabled Modules: %1, Proposals: %2",
        ProductControl.GetDisabledModules,
        ProductControl.GetDisabledProposals
      )

      UpdateWizardSteps()

      nil
    end

    def SetXENExceptions
      # not in text-mode
      if !UI.TextMode
        # bnc #376945
        # problems with keyboard in xen
        if SCR.Read(path(".probe.xen")) == true
          Builtins.y2milestone("XEN in X detected: running xset")
          WFM.Execute(path(".local.bash"), "xset r off; xset m 1")
          # bnc #433338
          # enabling key-repeating
        else
          Builtins.y2milestone("Enabling key-repeating")
          WFM.Execute(path(".local.bash"), "xset r on")
        end
      end

      nil
    end

    # Writes to /etc/install.inf whether running the second stage is required
    # This is written to inst-sys and not copied to the installed system
    # (which is already umounted in that time).
    #
    # @see BNC #439572
    def WriteSecondStageRequired(scst_required)
      # writes 'SecondStageRequired' '1' or '0'
      # if such tag exists, it is removed before
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "sed --in-place '/^%1: .*/D' %3; echo '%1: %2' >> %3",
          "SecondStageRequired",
          scst_required == false ? "0" : "1",
          "/etc/install.inf"
        )
      )
      Linuxrc.ResetInstallInf

      nil
    end
  end
end

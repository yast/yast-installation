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
      Builtins.y2milestone("InjectFile: <%1>", filename)
      WFM.Execute(
        path(".local.bash"),
        Ops.add(
          Ops.add(
            Ops.add(Ops.add("/bin/cp ", filename), " "),
            Installation.destdir
          ),
          filename
        )
      )
      nil 

      # this just needs too much memory
      # byteblock copy_buffer = WFM::Read (.local.byte, filename);
      # return SCR::Write (.target.byte, filename, copy_buffer);
    end


    def InjectRenamedFile(dir, src_name, target_name)
      Builtins.y2milestone(
        "InjectRenamedFile: <%1/%2> -> <%3/%4/%5>",
        dir,
        src_name,
        Installation.destdir,
        dir,
        target_name
      )
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "/bin/cp %1/%2 %3/%4/%5",
          dir,
          src_name,
          Installation.destdir,
          dir,
          target_name
        )
      )
      nil
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

    # moved from clients/inst_doit.ycp
    # to fix bug #219097

    # Confirm installation or update.
    # Returns 'true' if the user confirms, 'false' otherwise.
    #
    def confirmInstallation
      heading = ""
      body = ""
      confirm_button_label = ""

      if !Mode.update
        # Heading for confirmation popup before the installation really starts
        heading = HTML.Heading(_("Confirm Installation"))

        # Text for confirmation popup before the installation really starts 1/3
        body = _(
          "<p>Information required for the base installation is now complete.</p>"
        )

        some_destructive = Storage.GetCommitInfos.any? do |info|
          Ops.get_boolean(info, :destructive, false)
        end

        if some_destructive
          # Text for confirmation popup before the installation really starts 2/3
          body = Ops.add(
            body,
            _(
              "<p>If you continue now, <b>existing\n" \
                "partitions</b> on your hard disk will be <b>deleted</b> or <b>formatted</b>\n" \
                "(<b>erasing any existing data</b> in those partitions) according to the\n" \
                "installation settings in the previous dialogs.</p>"
            )
          )
        else
          # Text for confirmation popup before the installation really starts 2/3
          body = Ops.add(
            body,
            _(
              "<p>If you continue now, partitions on your\n" \
                "hard disk will be modified according to the installation settings in the\n" \
                "previous dialogs.</p>"
            )
          )
        end

        # Text for confirmation popup before the installation really starts 3/3
        body = Ops.add(
          body,
          _("<p>Go back and check the settings if you are unsure.</p>")
        )

        confirm_button_label = Label.InstallButton
      else
        # Heading for confirmation popup before the update really starts
        heading = HTML.Heading(_("Confirm Update"))

        body =
          # Text for confirmation popup before the update really starts 1/3
          _("<p>Information required to perform an update is now complete.</p>") +
            # Text for confirmation popup before the update really starts 2/3
            _(
              "\n" \
                "<p>If you continue now, data on your hard disk will be overwritten\n" \
                "according to the settings in the previous dialogs.</p>"
            ) +
            # Text for confirmation popup before the update really starts 3/3
            _("<p>Go back and check the settings if you are unsure.</p>")

        # Label for the button that confirms startint the installation
        confirm_button_label = _("Start &Update")
      end

      display_info = UI.GetDisplayInfo
      size_x = Builtins.tointeger(Ops.get_integer(display_info, "Width", 800))
      size_y = Builtins.tointeger(Ops.get_integer(display_info, "Height", 600))

      # 576x384 support for for ps3
      # bugzilla #273147
      if Ops.greater_or_equal(size_x, 800) && Ops.greater_or_equal(size_y, 600)
        size_x = 70
        size_y = 18
      else
        size_x = 54
        size_y = 15
      end

      UI.OpenDialog(
        VBox(
          VSpacing(0.4),
          HSpacing(size_x), # force width
          HBox(
            HSpacing(0.7),
            VSpacing(size_y), # force height
            RichText(heading + body),
            HSpacing(0.7)
          ),
          ButtonBox(
            PushButton(
              Id(:cancel),
              Opt(:cancelButton, :key_F10, :default),
              Label.BackButton
            ),
            PushButton(Id(:ok), Opt(:okButton, :key_F9), confirm_button_label)
          )
        )
      )

      button = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog

      button == :ok
    end

    # Some client calls have to be called even if using AC
    def EnableRequiredModules
      # Lazy init
      if @modules_to_enable_with_AC_on.nil?
        feature = ProductFeatures.GetFeature(
          "globals",
          "autoconfiguration_enabled_modules"
        )

        if feature == "" || feature.nil? || feature == []
          @modules_to_enable_with_AC_on = []
        else
          @modules_to_enable_with_AC_on = Convert.convert(
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

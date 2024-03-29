# Copyright (c) [2006-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "shellwords"

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

      @modules_to_enable_with_AC_on = nil
    end

    def InjectFile(filename)
      command = "/bin/cp #{filename.shellescape} #{File.join(Installation.destdir,
        filename).shellescape}"
      Builtins.y2milestone("InjectFile: <%1>", filename)
      Builtins.y2debug("Inject command: #{command}")
      WFM.Execute(path(".local.bash"), command)
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

    # Confirm installation or update
    #
    # @note moved from clients/inst_doit.ycp to fix bug #219097
    #
    # @return [Booelan] true if the user confirms; false otherwise
    def confirmInstallation
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
            RichText(Mode.update ? confirm_update_text : confirm_installation_text),
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

    # Text for confirmation popup before the installation really starts
    #
    # @return [String]
    def confirm_installation_text
      result = ""

      result << HTML.Heading(_("Confirm Installation"))
      result << _("<p>Information required for the base installation is now complete.</p>")
      result << _(
        "<p>If you continue now, partitions on your\n" \
        "hard disk will be modified according to the installation settings in the\n" \
        "previous dialogs.</p>"
      )
      result << _(
        "<p>Go back and check the settings if you are unsure.</p>"
      )
    end

    # Text for confirmation popup before the update really starts
    #
    # @return [String]
    def confirm_update_text
      result = ""

      result << HTML.Heading(_("Confirm Update"))
      result << _("<p>Information required to perform an update is now complete.</p>")
      result << _(
        "\n" \
        "<p>If you continue now, data on your hard disk will be overwritten\n" \
        "according to the settings in the previous dialogs.</p>"
      )
      result << _("<p>Go back and check the settings if you are unsure.</p>")
    end

    # Label for the confirmation button before starting the installation or update process
    #
    # @return [String]
    def confirm_button_label
      Mode.update ? _("Start &Update") : Label.InstallButton
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
          WFM.Execute(path(".local.bash"), "/usr/bin/xset r off; /usr/bin/xset m 1")
          # bnc #433338
          # enabling key-repeating
        else
          Builtins.y2milestone("Enabling key-repeating")
          WFM.Execute(path(".local.bash"), "/usr/bin/xset r on")
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
          "/usr/bin/sed --in-place '/^SecondStageRequired: .*/D' /etc/install.inf; " \
          "/usr/bin/echo 'SecondStageRequired: %1' >> /etc/install.inf",
          (scst_required == false) ? "0" : "1"
        )
      )
      # Is it really needed? It will enforce a read of /etc/install.inf from
      # any step after resetting it.
      Linuxrc.ResetInstallInf

      nil
    end
  end
end

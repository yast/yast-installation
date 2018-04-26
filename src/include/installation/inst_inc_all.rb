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

# File: include/installation/inst_inc_all.ycp
# Module: System installation
# Summary: Miscelaneous functions
# Authors: Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#

require "storage"

module Yast
  module InstallationInstIncAllInclude
    def initialize_installation_inst_inc_all(_include_target)
      Yast.import "UI"

      textdomain "installation"

      Yast.import "ProductControl"
      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "Wizard"
      Yast.import "Arch"
      Yast.import "Report"
      Yast.import "Installation"
      Yast.import "Stage"
      Yast.import "Mode"
    end

    def SetInitializingUI
      # dialog content - busy message
      ui_message = ""
      # help for the dialog - busy message
      ui_help = _("<p>Initializing the installation...</p>")

      # another texts for second stage
      if Stage.cont
        # dialog content - busy message
        ui_message = _("Preparing the 1st system configuration...")
        # help for the dialog - busy message
        ui_help = _("<p>Please wait...</p>")
      end

      Wizard.SetContents(
        # dialog caption
        _("Initializing..."),
        Label(ui_message),
        ui_help,
        false,
        false
      )
      Wizard.SetTitleIcon("yast-inst-mode")

      # gh#86 No control file found
      if ProductControl.current_control_file.nil?
        Yast.import "InstError"
        InstError.ShowErrorPopupWithLogs(
          # TRANSLATORS: Error message
          _("No installation control file has been found,\nthe installer cannot continue.")
        )
      end

      nil
    end

    def SetUIContent
      # Wizard::OpenNextBackStepsDialog();
      SetInitializingUI()

      nil
    end

    def SetGlobalInstallationFeatures
      # FATE #304395: Disabling (or handling) screensaver during installation
      # Disabling screen-saver on startup
      if WFM.Read(path(".local.size"), "/usr/bin/xset") != -1
        Builtins.y2milestone("Disabling Energy Star (DPMS) features")
        # DPMS off values, disable DPMS, disable screen-saver
        WFM.Execute(
          path(".local.bash"),
          "/usr/bin/xset dpms 0 0 0; /usr/bin/xset -dpms; /usr/bin/xset s 0 0; /usr/bin/xset s off"
        )
      end

      nil
    end

    def FinishInstallation(ret)
      Builtins.y2milestone("Finishing the installation...")

      if ret == :reboot || ret == :restart_yast || ret == :restart_same_step ||
          ret == :abort
        # TRANSLATORS: busy message
        UI.OpenDialog(Label(_("Writing YaST configuration..."))) # #2
      else
        # FATE #304395: Disabling (or handling) screensaver during installation
        # Enabling screen-saver on exit
        if WFM.Read(path(".local.size"), "/usr/bin/xset") != -1
          Builtins.y2milestone("Enabling Energy Star (DPMS) features")
          # default DPMS values, enable DPMS, enable screen-saver
          WFM.Execute(
            path(".local.bash"),
            "/usr/bin/xset dpms 1200 1800 2400; /usr/bin/xset +dpms; /usr/bin/xset s on; /usr/bin/xset s default;"
          )
        end

        # TRANSLATORS: busy message
        UI.OpenDialog(Label(_("Finishing the installation..."))) # #2
      end

      UI.CloseDialog # #2

      nil
    end

    # Sets autoinstallation behavior.
    def SetAutoinstHandling
      return if !Mode.autoinst

      reportMap = {
        "errors"         => { "timeout" => 0 },
        "warnings"       => { "timeout" => 10 },
        "yesno_messages" => { "timeout" => 10 }
      }
      Report.Import(reportMap)

      Report.DisplayErrors(true, 0)
      Report.DisplayWarnings(true, 10)
      Report.DisplayMessages(true, 10)

      nil
    end

    # Sets autoupgrade behavior
    def SetAutoupgHandling
      # if profile is defined, first read it, then probe hardware
      autoinstall = SCR.Read(path(".etc.install_inf.AutoYaST"))
      if !autoinstall.nil? && Ops.is_string?(autoinstall) &&
          Convert.to_string(autoinstall) != ""
        ProductControl.DisableModule("system_analysis")
        ProductControl.DisableModule("update_partition_auto")
      end

      nil
    end

    def ShowTextFallbackMessage
      if (Installation.text_fallback || Installation.no_x11) &&
          Installation.x11_setup_needed && Arch.x11_setup_needed &&
          !Installation.shown_text_mode_warning
        x11_msg = ""
        if (Installation.no_x11 || Installation.text_fallback) && Stage.initial
          # Somehow the graphical frontend failed and we're running in
          # text mode. Inform the user about this fact.
          x11_msg = Builtins.sformat(
            _(
              "Your computer does not fulfill all requirements for\n" \
                "a graphical installation. There is either less than %1 MB\n" \
                "memory or the X server could not be started.\n" \
                "\n" \
                "As fallback, the text front-end of YaST2 will guide you\n" \
                "through the installation. This front-end offers the\n" \
                "same functionality as the graphical one, but the screens\n" \
                "differ from those in the manual.\n"
            ),
            "96"
          )
        elsif (Installation.no_x11 || Installation.text_fallback) && Stage.cont
          # The script YaST2 wants to inform about a problem with the
          # option no_x11 but it's broken.
          # else if (Installation::no_x11 ())

          # Somehow the graphical frontend failed and we're running in
          # text mode. Inform the user about this fact.
          x11_msg = _(
            "The graphical interface could not be started.\n" \
              "\n" \
              "Either the required packages were not installed (minimal installation) \n" \
              "or the graphics card is not properly supported.\n" \
              "\n" \
              "As fallback, the text front-end of YaST2 will guide you\n" \
              "through the installation. This front-end offers the\n" \
              "same functionality as the graphical one, but the screens\n" \
              "differ from those in the manual.\n"
          )
        end

        if x11_msg != ""
          Report.Message(x11_msg)
        else
          Builtins.y2error(
            "There should be a more detailed message displayed here,\nbut something went wrong, that's why it is only in the log"
          )
        end

        # show this warning only once
        Installation.shown_text_mode_warning = true
      end

      nil
    end

    # Re-translate static part of wizard dialog and other predefined messages
    # after language change
    def retranslateWizardDialog
      Builtins.y2milestone("Retranslating messages")

      # Make sure the labels for default function keys are retranslated, too.
      # Using Label::DefaultFunctionKeyMap() from Label module.
      UI.SetFunctionKeys(Label.DefaultFunctionKeyMap)

      # Activate language changes on static part of wizard dialog
      ProductControl.RetranslateWizardSteps
      Wizard.RetranslateButtons
      Wizard.SetFocusToNextButton
      nil
    end

    def SetDiskActivationModule
      # update the workflow according to current situation
      # disable disks activation if not needed
      iscsi = Linuxrc.InstallInf("WithiSCSI") == "1"
      fcoe = Linuxrc.InstallInf("WithFCoE") == "1"
      no_disk = begin
        ::Storage.light_probe
      rescue ::Storage::Exception => e
        Builtins.y2milestone("light probe failed with #{e}")
        # is it safer when problem appear to act like there is no disk
        true
      end

      if !((Arch.s390 && !Arch.is_zkvm) || iscsi || fcoe || no_disk)
        Builtins.y2milestone("Disabling disk activation module")
        ProductControl.DisableModule("disks_activate")
      end

      nil
    end
  end
end

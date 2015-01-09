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

# File:	installation/general/inst_congratulate.ycp
# Module:	Installation
# Summary:	Display congratulation
# Authors:	Arvin Schnell <arvin@suse.de>
#
# Display a congratulation message for the user.
#
# $Id$
module Yast
  class InstCongratulateClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Mode"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "ProductFeatures"
      Yast.import "GetInstArgs"
      Yast.import "Call"
      Yast.import "Package"
      Yast.import "ProductControl"
      Yast.import "Stage"
      Yast.import "AddOnProduct"
      Yast.import "Service"

      @argmap = GetInstArgs.argmap

      # show button "clone system"?
      @show_clone_checkbox = !(Stage.firstboot || Mode.live_installation)
      @clone_checkbox_active = ProductFeatures.GetBooleanFeature(
        "globals",
        "enable_clone"
      )
      @clone_enabled = Package.Installed("autoyast2")

      # #302495: Switching ZMD off
      # by default, the checkbox is not visible
      @zmd_service_name = "novell-zmd"
      @zmd_package_name = "zmd"
      @check_box_turnoff_zmd = Empty()
      @turnoff_zmd_help = ""

      # See FATE #302495
      # Param 'show_zmd_turnoff_checkbox' says whether the checkbox for stopping and
      # disabling ZMD should be shown
      @show_zmd_turnoff_checkbox = Ops.get_string(
        @argmap,
        "show_zmd_turnoff_checkbox",
        "no"
      ) == "yes"

      # Param 'zmd_turnoff_default_state' says whether the checkbox is selected or
      # not by default
      @turnoff_zmd_default_state = Ops.get_string(
        @argmap,
        "zmd_turnoff_default_state",
        "no"
      ) == "yes"

      @zmd_installed = Package.Installed(@zmd_package_name)
      # don't check for state a service that is not installed
      @zmd_enabled_or_running = @zmd_installed &&
        (Service.Enabled(@zmd_service_name) ||
          Service.Status(@zmd_service_name) == 0)
      Builtins.y2milestone(
        "ZMD Installed: %1, Enabled/Running: %2",
        @zmd_installed,
        @zmd_enabled_or_running
      )
      Builtins.y2milestone(
        "Show TurnOffZMD checkbox: %1, default state: %2",
        @show_zmd_turnoff_checkbox,
        @turnoff_zmd_default_state
      )

      # + 'show_zmd_turnoff_checkbox'
      # + ZMD package needs to be installed
      # + ZMD service needs to be enabled
      if @show_zmd_turnoff_checkbox && @zmd_installed && @zmd_enabled_or_running
        @check_box_turnoff_zmd = CheckBox(
          Id(:turnoff_zmd),
          # TRANSLATORS: check box, see #ZMD
          _("&Disable ZMD Service"),
          # control_file->software->zmd_turnoff_default_state
          # says whether the checkbox is selected or not by default
          @turnoff_zmd_default_state
        )

        # TRANSLATORS: help text, see #ZMD
        @turnoff_zmd_help = _(
          "<p>Select <b>Disable ZMD Service</b> to stop and disable\nthe ZMD service during system start.</p>\n"
        )
      else
        Builtins.y2milestone("ZMD Turnoff check-box will be invisible")
      end

      @display = UI.GetDisplayInfo
      @space = Ops.get_boolean(@display, "TextMode", true) ? 1 : 3
      @vendor_url_tmp = ProductFeatures.GetStringFeature(
        "globals",
        "vendor_url"
      )

      # fallback
      @vendor_url = "http://www.suse.com/"
      if ProductFeatures.GetStringFeature("globals", "ui_mode") == "simple"
        @vendor_url = "http://www.openSUSE.org"
      end
      Builtins.y2milestone(
        "UI mode: %1",
        ProductFeatures.GetStringFeature("globals", "ui_mode")
      )

      if !@vendor_url_tmp.nil? && @vendor_url_tmp != ""
        @vendor_url = @vendor_url_tmp
      end

      @check_box_do_clone = Empty()

      if @show_clone_checkbox
        @check_box_do_clone = CheckBox(
          Id(:do_clone),
          # Check box: start the clone process and store the AutoYaST
          # profile in /root/autoinst.xml
          _("&Clone This System for AutoYaST"),
          @clone_checkbox_active
        )
      end

      # caption for dialog "Congratulation Dialog"
      @caption = _("Installation Completed")

      @text = ProductControl.GetTranslatedText("congratulate")

      if @text == ""
        # congratulation text 1/4
        @text = Ops.add(
          Ops.add(
            _("<p><b>Congratulations!</b></p>") +
              # congratulation text 2/4
              _(
                "<p>The installation of &product; on your machine is complete.\nAfter clicking <b>Finish</b>, you can log in to the system.</p>\n"
              ),
            # congratulation text 3/4
            Builtins.sformat(_("<p>Visit us at %1.</p>"), @vendor_url)
          ),
          # congratulation text 4/4
          _("<p>Have a lot of fun!<br>Your SUSE Development Team</p>")
        )
      else
        @text = Builtins.sformat(@text, @vendor_url)
      end

      @contents = VBox(
        VSpacing(@space),
        HBox(
          HSpacing(Ops.multiply(2, @space)),
          VBox(
            RichText(Id(:text), @text),
            VSpacing(Ops.divide(@space, 2)),
            Left(@check_box_turnoff_zmd),
            Left(@check_box_do_clone)
          ),
          HSpacing(Ops.multiply(2, @space))
        ),
        VSpacing(@space),
        VSpacing(2)
      )

      @help_file = ""
      # help 1/4 for dialog "Congratulation Dialog"
      @help = _("<p>Your system is ready for use.</p>") +
        # help 2/4 for dialog "Congratulation Dialog"
        _(
          "<p><b>Finish</b> will close the YaST installation and take you\nto the login screen.</p>\n"
        ) +
        # help 3/4 for dialog "Congratulation Dialog"
        (DisplayKDEHelp() ?
          _(
            "<p>If you choose the default graphical desktop KDE, you can\n" \
              "adjust some KDE settings to your hardware. Also notice\n" \
              "our SUSE Welcome Dialog.</p>\n"
          ) :
          "") # Show this help only in case of KDE as the default windowmanager

      if @show_clone_checkbox
        @help = Ops.add(
          @help,
          _(
            "<p>Use <b>Clone</b> if you want to create an AutoYaST profile.\n" \
              "AutoYaST is a way to do a complete SUSE Linux installation without user interaction. AutoYaST\n" \
              "needs a profile to know what the installed system should look like. If this option is\n" \
              "selected, a profile of the current system is stored in <tt>/root/autoinst.xml</tt>.</p>"
          )
        )
      end
      @help = Ops.add(@help, @turnoff_zmd_help) if @show_zmd_turnoff_checkbox

      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      Wizard.SetTitleIcon("yast-license")

      Wizard.SetNextButton(:next, Label.FinishButton)
      Wizard.RestoreAbortButton
      Wizard.SetFocusToNextButton
      if UI.WidgetExists(Id(:do_clone))
        UI.ChangeWidget(Id(:do_clone), :Enabled, @clone_enabled)
      end

      @ret = nil
      loop do
        @ret = Wizard.UserInput

        if @ret == :abort
          break if Popup.ConfirmAbort(:incomplete)
        elsif @ret == :help
          Wizard.ShowHelp(@help)
        end
        break if [:next, :back].include?(@ret)
      end

      # bugzilla #221190
      if @ret == :back
        Wizard.RestoreNextButton
      elsif @ret == :next
        # BNC #441452
        # Remove the congrats dialog
        @zmd = UI.WidgetExists(Id(:turnoff_zmd)) &&
          Convert.to_boolean(UI.QueryWidget(Id(:turnoff_zmd), :Value))
        @clone = UI.WidgetExists(Id(:do_clone)) &&
          Convert.to_boolean(UI.QueryWidget(Id(:do_clone), :Value))

        # Dialog busy message
        Wizard.SetContents(
          @caption,
          Label(_("Finishing the installation...")),
          @help,
          GetInstArgs.enable_back,
          GetInstArgs.enable_next
        )

        StopAndDisableZMD() if @zmd

        CallCloning() if @clone
      end

      # save all sources and finish target
      # bnc #398315
      Pkg.SourceSaveAll
      Pkg.TargetFinish

      deep_copy(@ret)
    end

    # Function returns true when the default windowmanager is KDE
    # See bug 170880 for more information
    #
    # @return [Boolean] wm is is_kde
    def DisplayKDEHelp
      default_wm = Convert.to_string(
        SCR.Read(path(".sysconfig.windowmanager.\"DEFAULT_WM\""))
      )
      Builtins.y2debug("Default WM: %1", default_wm)

      if !default_wm.nil? &&
          Builtins.issubstring(Builtins.tolower(default_wm), "kde")
        return true
      end
      false
    end

    def CallCloning
      # #187558
      # Load Add-On products configured in the fist stage
      AddOnProduct.ReadTmpExportFilename

      if !Package.InstallMsg(
        "autoyast2",
        _(
          "<p>To clone the current system, the <b>%1</b> package must be installed.</p>"
        ) +
          _("<p>Install it now?</p>")
        )
        Popup.Error(_("autoyast2 package not installed. Cloning disabled."))
      else
        # #165860
        # Save sources now because cloning garbles the target
        # Cloning reinitializes sources when it needs them
        Pkg.SourceSaveAll

        Call.Function("clone_system", [])
      end

      nil
    end

    def StopAndDisableZMD
      Builtins.y2milestone(
        "Stopping service: %1 -> %2",
        @zmd_service_name,
        Service.Stop(@zmd_service_name)
      )
      Builtins.y2milestone(
        "Disabling service: %1 -> %2",
        @zmd_service_name,
        Service.Disable(@zmd_service_name)
      )

      nil
    end
  end
end

Yast::InstCongratulateClient.new.main

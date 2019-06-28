# ------------------------------------------------------------------------------
# Copyright (c) [2006-2014] Novell, Inc. All Rights Reserved.
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

# File:  clients/inst_disks_activate.ycp
# Package:  Activation of disks (DASD, zFCP, iSCSI) during installation
# Summary:  Main file
# Authors:  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#

require "y2storage"
require "installation/clients/inst_update_installer"

module Yast
  class InstDisksActivateClient < Client
    def main
      Yast.import "UI"

      # **
      # <h3>Initialization of the disks</h3>

      textdomain "installation"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Disk activation module started")

      Yast.import "Arch"
      Yast.import "GetInstArgs"
      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "Popup"
      Yast.import "Wizard"

      # all the arguments
      @argmap = GetInstArgs.argmap

      @have_dasd = false
      @have_zfcp = false
      @want_fcoe = false

      if Arch.s390
        # popup label
        UI.OpenDialog(Label(_("Detecting Available Controllers")))

        # detect DASD disks
        disks = SCR.Read(path(".probe.disk"))
        @have_dasd = disks.any? { |d| d["device"] == "DASD" }

        # detect zFCP disks
        controllers = SCR.Read(path(".probe.storage"))
        @have_zfcp = controllers.any? { |c| c["device"] == "zFCP controller" }

        UI.CloseDialog
      end

      @want_fcoe = Linuxrc.InstallInf("WithFCoE") == "1"

      missing_part = [
        VSpacing(0),
        VSpacing(0)
      ]

      dasd_part = if @have_dasd
        button_with_spacing(:dasd, _("Configure &DASD Disks"))
      else
        missing_part
      end

      zfcp_part = if @have_zfcp
        button_with_spacing(:zfcp, _("Configure &ZFCP Disks"))
      else
        missing_part
      end

      fcoe_part = if @want_fcoe
        button_with_spacing(:fcoe, _("Configure &FCoE Interfaces"))
      else
        missing_part
      end

      @contents =
        VBox(
          network_button,
          VStretch(),
          HSquash(
            VBox(
              *dasd_part,
              *zfcp_part,
              *fcoe_part,
              *button_with_spacing(:iscsi, _("Configure &iSCSI Disks"))
            )
          ),
          VStretch()
        )

      @disks_changed = false

      while @ret.nil?
        show_base_dialog
        @ret = UI.UserInput

        case @ret
        when :dasd
          WFM.call("inst_dasd")
          @ret = :redraw
        when :zfcp
          WFM.call("inst_zfcp")
          @ret = :redraw
        when :iscsi
          WFM.call("inst_iscsi-client", [@argmap])
          @ret = :redraw
        when :fcoe
          WFM.call("inst_fcoe-client", [@argmap])
          @ret = :redraw
        when :network
          WFM.call("inst_lan", [@argmap.merge("skip_detection" => true)])
          @ret = :redraw
        when :abort
          @ret = nil unless Popup.ConfirmAbort(:painless)
        end

        if @ret == :redraw
          @disks_changed = true
          @ret = nil
        end
      end

      Y2Storage::StorageManager.instance.probe if @disks_changed

      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Disk activation module finished")
      Builtins.y2milestone("----------------------------------------")

      @ret
    end

  private

    def network_button
      Right(PushButton(Id(:network), _("Net&work Configuration...")))
    end

    def show_base_dialog
      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Disk Activation"),
        @contents,
        help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )

      RestoreButtons(GetInstArgs.enable_back, GetInstArgs.enable_next)
      Wizard.SetFocusToNextButton
    end

    def button(id, title)
      HWeight(
        1,
        PushButton(
          Id(id),
          Opt(:hstretch),
          title
        )
      )
    end

    def button_with_spacing(id, title)
      [button(id, title), VSpacing(2)]
    end

    def RestoreButtons(enable_back, enable_next)
      Wizard.RestoreAbortButton
      Wizard.RestoreNextButton
      Wizard.RestoreBackButton

      enable_back ? Wizard.EnableBackButton : Wizard.DisableBackButton
      enable_next ? Wizard.EnableNextButton : Wizard.DisableNextButton
    end

    def help
      network_button_help +
        dasd_button_help +
        zfcp_button_help +
        fcoe_button_help +
        iscsi_button_help
    end

    def network_button_help
      # TRANSLATORS: Help text for "Network configuration..." button in the Disks activation dialog
      _("<h2>Network configuration</h2>" \
        "Launches the Network configuration dialog.")
    end

    def dasd_button_help
      return "" unless @have_dasd

      # TRANSLATORS: Help text for "Configure DASD Disks" button in the Disks activation dialog
      _("<h2>Configure DASD Disks</h2>" \
        "Opens the dialog to configure the " \
        "<b>D</b>irect <b>A</b>ccess <b>S</b>torage <b>D</b>isks.")
    end

    def zfcp_button_help
      return "" unless @have_zfcp

      # TRANSLATORS: Help text for "Configure zFCP Disks" button in the Disks activation dialog
      _("<h2>Configure zFCP Disks</h2>" \
        "Allows to configure the Fibre Channel Attached SCSI Disks.")
    end

    def fcoe_button_help
      return "" unless @want_fcoe

      # TRANSLATORS: Help text for "Configure FCoE Interfaces" button in the Disks activation dialog
      _("<h2>Configure FCoE Interfaces</h2>" \
        "Shows the dialog to manage the " \
        "<b>F</b>ibre <b>C</b>hannel <b>o</b>ver <b>E</b>thernet interfaces.")
    end

    def iscsi_button_help
      # TRANSLATORS: Help text for "Configure iSCSI Disks" button in the Disks activation dialog
      _("<h2>Configure iSCSI Disks</h2>" \
        "Executes the iSCSI initiator configuration.")
    end
  end
end

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

# File:	clients/inst_disks_activate.ycp
# Package:	Activation of disks (DASD, zFCP, iSCSI) during installation
# Summary:	Main file
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class InstDisksActivateClient < Client
    def main
      Yast.import "UI"

      #**
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
      Yast.import "Storage"
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
        @have_dasd = disks.any? {|d| d["device"] == "dasd" }

        # detect zFCP disks
        controllers = SCR.Read(path(".probe.storage"))
        @have_zfcp = controllers.any? {|c| c["device"] == "zFCP controller" }

        UI.CloseDialog
      end

      @want_fcoe = Linuxrc.InstallInf("WithFCoE") == "1"


      # dialog caption
      @caption = _("Disk Activation")

      @help = ""

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
          button_with_spacing(:zfce, _("Configure &ZFCP Disks"))
        else
          missing_part
        end

      fcoe_part = if @want_fcoe
          button_with_spacing(:fcoe, _("Configure &FCoE Interfaces"))
        else
          missing_part
        end


      @contents = HBox(
        HWeight(999, HStretch()),
        VBox(
          VStretch(),
          *dasd_part,
          *fcoe_part,
          *fcoe_part,
          button(:iscsi, _("Configure &iSCSI Disks")),
          VStretch()
        ),
        HWeight(999, HStretch())
      )

      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      Wizard.SetTitleIcon("disk")
      Wizard.SetFocusToNextButton

      @ret = nil
      @disks_changed = false
      while @ret == nil
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
        end
        if @ret == :redraw
          @disks_changed = true
          Wizard.SetContents(
            @caption,
            @contents,
            @help,
            GetInstArgs.enable_back,
            GetInstArgs.enable_next
          )
          Wizard.SetTitleIcon("disk")
          Wizard.SetFocusToNextButton
          @ret = nil
        end
        RestoreButtons(GetInstArgs.enable_back, GetInstArgs.enable_next)
      end

      if @have_dasd && @ret == :next
        @cmd = "/sbin/dasd_reload"
        Builtins.y2milestone(
          "Initialize cmd %1 ret %2",
          @cmd,
          SCR.Execute(path(".target.bash_output"), @cmd)
        )
      end

      Storage.ReReadTargetMap if @disks_changed

      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Disk activation module finished")
      Builtins.y2milestone("----------------------------------------")

      @ret
    end

  private

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
      [ button(id, title), VSpacing(2) ]
    end

    def RestoreButtons(enable_back, enable_next)
      Wizard.RestoreAbortButton
      Wizard.RestoreNextButton
      Wizard.RestoreBackButton
      if enable_back
        Wizard.EnableBackButton
      else
        Wizard.DisableBackButton
      end
      if enable_next
        Wizard.EnableNextButton
      else
        Wizard.DisableNextButton
      end
    end
  end
end

Yast::InstDisksActivateClient.new.main

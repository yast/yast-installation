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

# File:        clients/inst_ask_online_update.ycp
# Module:      Installation
# Summary:     Ask if the user wants to run an online update during installation
# Authors:     J. Daniel Schmidt <jdsn@suse.de>
#
# Ask if the user wants to run an online update during installation
#
# $Id: inst_ask_online_update.ycp 1 2006-02-17 13:20:02Z jdsn $
module Yast
  class InstAskOnlineUpdateClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "installation"

      # FIXME: move to yast2-registration later, it doesn't belog here

      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "GetInstArgs"
      Yast.import "CustomDialogs"
      Yast.import "Directory"
      Yast.import "Language"
      Yast.import "Mode"
      Yast.import "String"
      Yast.import "Label"
      Yast.import "Internet"
      Yast.import "Installation"
      Yast.import "NetworkService"

      # BNC #572734
      if GetInstArgs.going_back
        Builtins.y2milestone("going_back -> returning `auto")
        return :auto
      end

      # BNC #450229
      # There used to be >if (!Internet::do_you)<
      if NetworkService.isNetworkRunning != true
        Builtins.y2milestone("No network running, skipping online update...")
        return :auto
      end

      @ui = UI.GetDisplayInfo

      @argmap = GetInstArgs.argmap


      #  strings for "ask for online update"-popup
      @ask_update_run_btn = _("Run Update")
      @ask_update_skip_btn = _("Skip Update")

      @online_update = _("Online Update")
      @ask_update_main = _("Run Online Update now?")

      @help = _(
        "Select whether to run an online update now.\nYou may skip this step and run an online update later.\n"
      )

      # vv   MAIN (WIZARD) LAYOUT  vv
      @sr_layout = nil
      @sr_layout = HVSquash(
        VBox(
          Left(Label(@ask_update_main)),
          Left(
            RadioButtonGroup(
              Id(:run_update),
              HBox(
                HSpacing(1),
                VBox(
                  Left(RadioButton(Id(:update), @ask_update_run_btn, true)),
                  Left(RadioButton(Id(:noupdate), @ask_update_skip_btn))
                ),
                HSpacing(1)
              )
            )
          )
        )
      )

      @contents = VBox(VSpacing(0.5), @sr_layout, VSpacing(0.5))
      # ^^       END MAIN LAYOUT     ^^

      # check if there are some patches available

      # BNC #447080
      Pkg.TargetInitialize(Installation.destdir)
      Pkg.TargetLoad
      Pkg.SourceStartManager(true)

      # Patches need solver run to be selected
      Pkg.PkgSolve(true)

      @selected = Pkg.ResolvableCountPatches(:affects_pkg_manager)
      Builtins.y2milestone(
        "Available patches for pkg management: %1",
        @selected
      )
      if Ops.less_than(@selected, 1)
        @selected = Pkg.ResolvableCountPatches(:all)
        Builtins.y2milestone("All available patches: %1", @selected)
        if Ops.less_than(@selected, 1)
          Builtins.y2milestone("No patch available, skiping offer to run YOU")
          Internet.do_you = false
          return :next
        end
      end

      # check if we are in installation workflow or running independently (for development)
      Wizard.CreateDialog if Mode.normal

      Wizard.SetContents(
        @online_update,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )

      @ret = nil
      loop do
        @ret = Wizard.UserInput

        if @ret == :abort
          break if Mode.normal
          break if Popup.ConfirmAbort(:incomplete)
        elsif @ret == :help
          Wizard.ShowHelp(@help)
        elsif @ret == :next
          # Skipping online update
          if Convert.to_boolean(UI.QueryWidget(Id(:noupdate), :Value))
            Internet.do_you = false
          else
            # needed later
            # BNC #450229
            Internet.do_you = true
          end
        end
        break if [:next, :back].include?(@ret)
      end

      Convert.to_symbol(@ret)
    end
  end
end

Yast::InstAskOnlineUpdateClient.new.main

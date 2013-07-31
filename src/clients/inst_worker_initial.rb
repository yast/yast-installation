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

# File:		inst_worker_initial.ycp
#
# Authors:		Klaus Kaempf <kkaempf@suse.de>
#			Mathias Kettner <kettner@suse.de>
#			Michael Hager <mike@suse.de>
#			Stefan Hundhammer <sh@suse.de>
#			Arvin Schnell <arvin@suse.de>
#			Jiri Srain <jsrain@suse.cz>
#			Lukas Ocilka <locilka@suse.cz>
#
# Purpose:		Set up the UI and define macros for the
#			installation dialog, general framework, ...
#			Describing and calling all submodules.
#			(For initial installation only).
#
# $Id$
module Yast
  class InstWorkerInitialClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Installation"
      Yast.import "Linuxrc"
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "Stage"

      # General installation functions
      Yast.include self, "installation/misc.rb"
      # Both First & Second stage-related functions
      Yast.include self, "installation/inst_inc_all.rb"
      # First-stage-related functions only
      Yast.include self, "installation/inst_inc_first.rb"

      # --- First, connect to the system via SCR ---

      # this is installation, so start SCR always locally (as plugin) !
      @scr_handle = WFM.SCROpen("scr", false)
      WFM.SCRSetDefault(@scr_handle)

      Installation.scr_handle = @scr_handle

      # --- Global settings ---

      # All stages
      SetAutoinstHandling()
      SetAutoupgHandling()
      SetGlobalInstallationFeatures()

      # Initial stage
      SetInitialInstallation()

      # Update initiated from running system
      SetSystemUpdate()

      # All stages
      SetUIContent()

      SetNetworkActivationModule()

      SetDiskActivationModule()

      # Cleanup and other settings
      InitFirstStageInstallationSystem()

      # Redraw steps before mouse is initialized
      # Bugzilla #296406
      UpdateWizardSteps()

      # Initial stage
      InitMouse()

      # All stages
      # Shows fallback message if running in textmode (if used as fallback)
      ShowTextFallbackMessage()

      # First stage
      if !Mode.screen_shot && !Stage.firstboot
        WFM.CallFunction("inst_check_autoinst_mode", [])
      end

      @ret = nil

      # --- Runing the installation workflow ---

      @ret = ProductControl.Run
      Builtins.y2milestone("ProductControl::Run() returned %1", @ret)

      # --- Handling finished installation workflow ---

      Builtins.y2milestone("Evaluating ret: %1", @ret)

      # Installation has been aborted
      if @ret == :abort
        # tell linuxrc that we aborted
        Linuxrc.WriteYaSTInf({ "Aborted" => "1" })
      end

      # All Sources and Target need to be released...
      FinishInstallation(@ret)

      @ret
    end
  end
end

Yast::InstWorkerInitialClient.new.main

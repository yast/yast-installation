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

# File:		inst_worker_continue.ycp
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
#			(For continuing installation only).
#
# $Id$
module Yast
  class InstWorkerContinueClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"
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
      # Second-stage-related functions only
      Yast.include self, "installation/inst_inc_second.rb"

      # --- First, connect to the system via SCR ---

      # this is installation, so start SCR always locally (as plugin) !
      @scr_handle = WFM.SCROpen("scr", false)
      WFM.SCRSetDefault(@scr_handle)

      Installation.scr_handle = @scr_handle

      # --- Global settings ---

      # All stages
      SetAutoinstHandling()
      SetGlobalInstallationFeatures()

      # FATE #300422
      @ret = RerunInstallationIfAborted()
      return @ret if @ret != :next

      SetSecondStageInstallation()

      # All stages
      SetUIContent()

      AdjustDisabledItems()

      SetDiskActivationModule()

      UpdateWizardSteps()

      # Adjusts network services to the state in which they were
      # before rebooting the installation (e.g., inst_you)
      # bugzilla #258742
      InitNetworkServices()
      # Set "Initializing..." UI again
      SetInitializingUI()

      # Second stage
      SetLanguageAndEncoding()
      retranslateWizardDialog

      # All stages
      # Shows fallback message if running in textmode (if used as fallback)
      ShowTextFallbackMessage()

      @ret = nil

      # --- Runing the installation workflow ---

      # Continue the second stage installation
      if FileUtils.Exists(Installation.restart_data_file)
        @contents = Convert.to_string(
          SCR.Read(path(".target.string"), Installation.restart_data_file)
        )
        # file will be created if it is needed
        Builtins.y2milestone(
          "Removing %1 file containing %2",
          Installation.restart_data_file,
          @contents
        )
        SCR.Execute(path(".target.remove"), Installation.restart_data_file)

        @contents_lines = Builtins.splitstring(@contents, "\n")
        @next_step = Builtins.tointeger(Ops.get(@contents_lines, 0))
        @restarting_step = Builtins.tointeger(Ops.get(@contents_lines, 1))

        if @next_step == nil
          Builtins.y2error("Data file specifying step to continue corrupted")
          ProductControl.first_step = 0
          ProductControl.restarting_step = nil
          @ret = ProductControl.Run
          Builtins.y2milestone("ProductControl::Run() returned %1", @ret)
        else
          ProductControl.first_step = @next_step
          ProductControl.restarting_step = @restarting_step
          @ret = ProductControl.RunFrom(@next_step, false)
          Builtins.y2milestone(
            "ProductControl::RunFrom(%1) returned %2",
            @next_step,
            @ret
          )
        end

        CleanUpRestartFiles() 
        # Starting the second stage installation
      else
        # Run the installation workflow
        @ret = ProductControl.Run
        Builtins.y2milestone("ProductControl::Run() returned %1", @ret)
      end

      # --- Handling finished installation workflow ---

      Builtins.y2milestone("Evaluating ret: %1", @ret)

      if @ret == :reboot || @ret == :restart_yast || @ret == :restart_same_step ||
          @ret == :reboot_same_step
        @ret = PrepareYaSTforRestart(@ret) 
        # Installation has been aborted
      elsif @ret == :abort
        # tell linuxrc that we aborted
        Linuxrc.WriteYaSTInf( "Aborted" => "1" )
      end

      # Store network services to the state in which they are
      # before rebooting the installation (e.g., inst_you)
      # bugzilla #258742
      StoreNetworkServices(@ret)

      # when the installation is not aborted or YaST is not restarted on purpose
      # ret == `next -> (ret != `reboot && ret != `restart_yast && ret != `restart_same_step && ret != `abort && ret != `reboot_same_step)
      if @ret == :next
        HandleSecondStageFinishedCorrectly() 
        # installation (second stage) has been aborted
        # FATE #300422
      elsif @ret == :abort || @ret == :cancel
        HandleSecondStageAborted()
      end

      if @ret == :next || @ret == :abort || @ret == :cancel
        EnableAutomaticModuleProbing()
      end

      # All Sources and Target need to be released...
      FinishInstallation(@ret)

      @ret
    end
  end
end

Yast::InstWorkerContinueClient.new.main

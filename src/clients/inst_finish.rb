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

# File:	clients/inst_finish.ycp
# Package:	installation
# Summary:	Finish installation
# Authors:	Klaus Kämpf <kkaempf@suse.de>
#		Arvin Schnell <arvin@suse.de>
#              Jiri Srain <jsrain@suse.de>
#
# $Id$
module Yast
  class InstFinishClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"
      textdomain "installation"

      Yast.import "AddOnProduct"
      Yast.import "WorkflowManager"
      Yast.import "Installation"
      Yast.import "Linuxrc"
      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Wizard"
      Yast.import "String"
      Yast.import "GetInstArgs"
      Yast.import "ProductFeatures"
      Yast.import "SlideShow"
      Yast.import "InstError"
      Yast.import "PackageCallbacks"

      # added for fate# 303395
      Yast.import "Directory"

      return :auto if GetInstArgs.going_back

      # <-- Functions

      @test_mode = false

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        Builtins.y2milestone("Args: %1", WFM.Args)
        @test_mode = true if WFM.Args(0) == "test"
      end

      Wizard.CreateDialog if @test_mode

      Wizard.DisableBackButton
      Wizard.DisableNextButton

      # Adjust a SlideShow dialog if not configured
      @get_setup = SlideShow.GetSetup
      if @get_setup == nil || @get_setup == {}
        Builtins.y2milestone("No SlideShow setup has been set, adjusting")
        SlideShow.Setup(
          [
            {
              "name"        => "finish",
              "description" => _("Finishing Basic Installation"),
              # fixed value
              "value"       => 100,
              "units"       => :sec
            }
          ]
        )
      end
      @get_setup = nil

      Wizard.SetTitleIcon("yast-sysconfig")

      # Do not open a new SlideShow widget, reuse the old one instead
      # variable used later to close that dialog (if needed)
      @required_to_open_sl_dialog = !SlideShow.HaveSlideWidget

      if @required_to_open_sl_dialog
        Builtins.y2milestone("SlideShow dialog not yet created")
        SlideShow.OpenDialog
      end

      # Might be left from the previous stage
      SlideShow.HideTable

      SlideShow.MoveToStage("finish")

      @log = _("Creating list of finish scripts to call...")
      SlideShow.SubProgress(0, "")
      SlideShow.StageProgress(0, @log)
      SlideShow.AppendMessageToInstLog(@log)

      # Used later in 'stages' definition
      # Using empty callbacks that don't break the UI
      PackageCallbacks.RegisterEmptyProgressCallbacks
      Pkg.TargetInitialize(Installation.destdir)
      Pkg.TargetLoad
      PackageCallbacks.RestorePreviousProgressCallbacks

      @stages = [
        {
          "id"    => "copy_files",
          # progress stage
          "label" => _("Copy files to installed system"),
          "steps" => [
            "autoinst_scripts1",
            "copy_files",
            "copy_systemfiles",
            # For live installer only
            Mode.live_installation ? "live_copy_files" : "",
            "switch_scr"
          ],
          "icon"  => "pattern-basis"
        },
        {
          "id"    => "save_config",
          # progress stage
          "label" => _("Save configuration"),
          "steps" => [
            "ldconfig",
            "save_config",
            # For live installer only
            Mode.live_installation ? "live_save_config" : "",
            "default_target",
            "desktop",
            "storage",
            "iscsi-client",
            "kernel",
            "x11",
            "proxy",
            "pkg",
            "driver_update1",
            "random",
            # bnc #340733
            "system_settings"
          ],
          "icon"  => "yast-desktop-select"
        },
        {
          "id"    => "install_bootloader",
          # progress stage
          "label" => _("Install boot manager"),
          "steps" => [
            "bootloader",
            ProductFeatures.GetBooleanFeature("globals", "enable_kdump") == true ? "kdump" : ""
          ],
          "icon"  => "yast-bootloader"
        },
        {
          "id"    => "save_settings",
          # progress stage
          "label" => _("Save installation settings"),
          "steps" => [
            "yast_inf",
            "network",
            "firewall_stage1",
            "ntp-client",
            "ssh_settings",
            "ssh_service",
            "save_hw_status",
            "users",
            "autoinst_scripts2",
            "installation_settings"
          ],
          "icon"  => "yast-network"
        },
        {
          "id"    => "prepare_for_reboot",
          # progress stage
          "label" => _("Prepare system for initial boot"),
          "steps" => [
            # For live installer only
            Mode.live_installation ? "live_runme_at_boot" : "",
            # vm_finish called only if yast2-vm is installed
            # Can't use PackageSystem::Installed as the current SCR is attached to inst-sys
            # instead of the installed system
            Pkg.PkgInstalled("yast2-vm") ? "vm" : "",
            "driver_update2",
            # no second stage if possible
            "pre_umount",
            # copy logs just before 'umount'
            # keeps maximum logs available after reboot
            "copy_logs",
            "umount"
          ],
          # bnc #438154
          "icon"  => Mode.live_installation ?
            "yast-live-install-finish" :
            "yast-scripts"
        }
      ]

      if Ops.greater_than(Builtins.size(ProductControl.inst_finish), 0)
        Builtins.y2milestone(
          "Using inst_finish steps definition from control file"
        )
        @stages = deep_copy(ProductControl.inst_finish)

        # Inst-finish need to be translated (#343783)
        @textdom = Ops.get_string(
          ProductControl.productControl,
          "textdomain",
          "control"
        )
        @stages_copy = deep_copy(@stages)

        Builtins.y2milestone("Inst finish stages before: %1", @stages)

        @counter = -1
        # going through copy, the original is going to be changed in the loop
        Builtins.foreach(@stages_copy) do |one_stage|
          @counter = Ops.add(@counter, 1)
          label = Ops.get_string(one_stage, "label", "")
          next if label == nil || label == ""
          loc_label = Builtins.dgettext(@textdom, label)
          # if translated
          if loc_label != nil && loc_label != "" && loc_label != label
            Ops.set(@stages, [@counter, "label"], loc_label)
          end
        end

        Builtins.y2milestone("Inst finish stages after: %1", @stages)
      else
        Builtins.y2milestone(
          "inst_finish steps definition not found in control file"
        )
      end

      # merge steps from add-on products
      # bnc #438678
      Ops.set(
        @stages,
        [0, "steps"],
        Builtins.merge(
          WorkflowManager.GetAdditionalFinishSteps("before_chroot"),
          Ops.get_list(@stages, [0, "steps"], [])
        )
      )
      Ops.set(
        @stages,
        [1, "steps"],
        Builtins.merge(
          WorkflowManager.GetAdditionalFinishSteps("after_chroot"),
          Ops.get_list(@stages, [1, "steps"], [])
        )
      )
      Ops.set(
        @stages,
        [3, "steps"],
        Builtins.merge(
          Ops.get_list(@stages, [3, "steps"], []),
          WorkflowManager.GetAdditionalFinishSteps("before_umount")
        )
      )

      @run_type = :installation
      if Mode.update
        @run_type = :update
      elsif Mode.autoinst
        @run_type = :autoinst
      elsif Mode.live_installation
        @run_type = :live_installation
      end

      @steps_count = 0

      @stages_to_check = Builtins.size(@stages)
      @currently_checking = 0

      @stages = Builtins.maplist(@stages) do |stage|
        @currently_checking = Ops.add(@currently_checking, 1)
        SlideShow.SubProgress(
          Ops.divide(Ops.multiply(100, @currently_checking), @stages_to_check),
          Builtins.sformat(
            _("Checking stage: %1..."),
            Ops.get_string(stage, "label", Ops.get_string(stage, "id", ""))
          )
        )
        steps = Builtins.maplist(Ops.get_list(stage, "steps", [])) do |s|
          # some steps are called in live installer only
          next nil if s == "" || s == nil
          s = Ops.add(s, "_finish")
          if !WFM.ClientExists(s)
            Builtins.y2error("Missing YCP client: %1", s)
            next nil
          end
          Builtins.y2milestone("Calling inst_finish script: %1 (Info)", s)
          orig = Progress.set(false)
          info = Convert.to_map(WFM.CallFunction(s, ["Info"]))
          if @test_mode == true
            info = {} if info == nil
            Builtins.y2milestone("Test mode, forcing run")
            Ops.set(info, "when", [:installation, :update, :autoinst])
          end
          Progress.set(orig)
          if info == nil
            Builtins.y2error("Client %1 returned invalid data", s)
            ReportClientError(
              Builtins.sformat("Client %1 returned invalid data.", s)
            )
            next nil
          end
          if Ops.get(info, "when") != nil &&
              !Builtins.contains(Ops.get_list(info, "when", []), @run_type) &&
              # special hack for autoupgrade - should be as regular upgrade as possible, scripts are the only exception
              !(Mode.autoupgrade &&
                Builtins.contains(Ops.get_list(info, "when", []), :autoupg))
            next nil
          end
          Builtins.y2milestone("inst_finish client %1 will be called", s)
          Ops.set(info, "client", s)
          @steps_count = Ops.add(
            @steps_count,
            Ops.get_integer(info, "steps", 1)
          )
          deep_copy(info)
        end
        Ops.set(stage, "steps", Builtins.filter(steps) { |s| s != nil })
        deep_copy(stage)
      end

      Builtins.y2milestone("These inst_finish stages will be called:")
      Builtins.foreach(@stages) do |stage|
        Builtins.y2milestone("Stage: %1", stage)
      end

      @stages = Builtins.filter(@stages) do |s|
        Ops.greater_than(Builtins.size(Ops.get_list(s, "steps", [])), 0)
      end

      @stage_names = Builtins.maplist(@stages) do |s|
        Ops.get_string(s, "label", "")
      end



      @aborted = false

      @stages_nr = Builtins.size(@stages)
      @current_stage = -1
      @current_stage_percent = 0
      @fallback_msg = nil

      Builtins.foreach(@stages) do |stage|
        if Ops.get_string(stage, "icon", "") != ""
          Wizard.SetTitleIcon(Ops.get_string(stage, "icon", ""))
        end
        @current_stage = Ops.add(@current_stage, 1)
        @current_stage_percent = Ops.divide(
          Ops.multiply(100, @current_stage),
          @stages_nr
        )
        SlideShow.StageProgress(
          @current_stage_percent,
          Ops.get_string(stage, "label", "")
        )
        SlideShow.AppendMessageToInstLog(Ops.get_string(stage, "label", ""))
        steps_nr = Builtins.size(Ops.get_list(stage, "steps", []))
        current_step = -1
        Builtins.foreach(Ops.get_list(stage, "steps", [])) do |step|
          current_step = Ops.add(current_step, 1)
          # a fallback busy message
          @fallback_msg = Builtins.sformat(
            _("Calling step %1..."),
            Ops.get_string(step, "client", "")
          )
          SlideShow.SubProgress(
            Ops.divide(Ops.multiply(100, current_step), steps_nr),
            Ops.get_string(step, "title", @fallback_msg)
          )
          SlideShow.StageProgress(
            Ops.add(
              @current_stage_percent,
              Ops.divide(
                Ops.multiply(Ops.divide(100, @stages_nr), current_step),
                steps_nr
              )
            ),
            nil
          )
          # use as ' * %1' -> ' * One of the finish steps...' in the SlideShow log
          SlideShow.AppendMessageToInstLog(
            Builtins.sformat(
              _(" * %1"),
              Ops.get_string(step, "title", @fallback_msg)
            )
          )
          orig = Progress.set(false)
          if @test_mode == true
            Builtins.y2milestone(
              "Test-mode, skipping  WFM::CallFunction (%1, ['Write'])",
              Ops.get_string(step, "client", "")
            )
            Builtins.sleep(500)
          else
            WFM.CallFunction(Ops.get_string(step, "client", ""), ["Write"])
          end
          Progress.set(orig)
          # Handle user input during client run
          user_ret = UI.PollInput
          # Aborting...?
          if user_ret == :abort
            if Popup.ConfirmAbort(:incomplete)
              @aborted = true
              raise Break
            end
            # Anything else
          else
            SlideShow.HandleInput(user_ret)
          end
        end
        raise Break if @aborted
        SlideShow.SubProgress(100, nil)
      end

      SlideShow.StageProgress(100, nil)
      SlideShow.AppendMessageToInstLog(_("Finished"))

      if @aborted
        Builtins.y2milestone("inst_finish aborted")
        return :abort
      end

      if @required_to_open_sl_dialog
        Builtins.y2milestone("Closing previously opened SlideShow dialog")
        SlideShow.CloseDialog
      end

      # --------------------------------------------------------------
      # Check if there is a message left to display
      # and display it, if necessary

      # Do not call any SCR, it's already closed!
      if Ops.greater_than(Builtins.size(Misc.boot_msg), 0) && !Mode.autoinst
        # bugzilla #245742, #160301
        if Linuxrc.usessh && !Linuxrc.vnc ||
            # also live installation - bzilla #297691
            Mode.live_installation
          # Display the message and wait for user to accept it
          Report.DisplayMessages(true, 0)
        else
          Report.DisplayMessages(true, 10)
        end
        Report.LongMessage(Misc.boot_msg)
        Misc.boot_msg = ""
      end

      if @test_mode
        Wizard.CloseDialog
        return :auto
      end

      # fate #303395: Use kexec to avoid booting between first and second stage
      # run new kernel via kexec instead of reboot

      # command for reading kernel_params
      @cmd = Builtins.sformat(
        "ls '%1/kexec_done' |tr -d '\n'",
        String.Quote(Directory.vardir)
      )
      Builtins.y2milestone(
        "Checking flag of successful loading kernel via command %1",
        @cmd
      )

      @out = Convert.to_map(WFM.Execute(path(".local.bash_output"), @cmd))

      @cmd = Builtins.sformat("%1/kexec_done", Directory.vardir)

      # check output
      if Ops.get_string(@out, "stdout", "") != @cmd
        Builtins.y2milestone("File kexec_done was not found, output: %1", @out)
        return :next
      end

      # hack for using kexec switch to console 1
      @cmd = Builtins.sformat("chvt 1")
      Builtins.y2milestone("Switch to console 1 via command: %1", @cmd)
      # switch to console 1
      @out = Convert.to_map(WFM.Execute(path(".local.bash_output"), @cmd))
      # check output
      if Ops.get(@out, "exit") != 0
        Builtins.y2error("Switching failed, output: %1", @out)
        return :next
      end

      # waiting s for switching...
      Builtins.sleep(1000)

      :next
    end

    # --> Functions

    def ReportClientError(client_error_text)
      # get the latest errors
      cmd = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          "tail -n 200 /var/log/YaST2/y2log | grep ' <\\(3\\|5\\)> '"
        )
      )

      InstError.ShowErrorPopUp(
        _("Installation Error"),
        client_error_text,
        Ops.get_integer(cmd, "exit", -1) == 0 &&
          Ops.get_string(cmd, "stdout", "") != "" ?
          Ops.get_string(cmd, "stdout", "") :
          nil
      )

      nil
    end
  end
end

Yast::InstFinishClient.new.main

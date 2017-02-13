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

require "installation/minimal_installation"

Yast.import "UI"
Yast.import "Pkg"

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
Yast.import "Hooks"

# added for fate# 303395
Yast.import "Directory"

module Yast
  class InstFinishClient < Client
    include Yast::Logger

    def main
      textdomain "installation"

      return :auto if GetInstArgs.going_back

      setup_wizard
      setup_slide_show

      init_packager

      aborted = !write

      finish_slide_show

      if aborted
        Builtins.y2milestone("inst_finish aborted")
        return :abort
      end

      report_hooks

      report_messages
      handle_kexec

      :next
    end

  private

    def write
      stages.each_with_index do |stage, index|
        if stage["icon"] && !stage["icon"].empty?
          Wizard.SetTitleIcon(stage["icon"])
        end
        current_stage_percent = 100 * index / stages.size
        SlideShow.StageProgress(
          current_stage_percent,
          stage["label"] || ""
        )
        SlideShow.AppendMessageToInstLog(stage["label"] || "")
        steps_nr = stage["steps"].size
        stage["steps"].each_with_index do |step, step_index|
          # a fallback busy message
          fallback_msg = Builtins.sformat(
            _("Calling step %1..."),
            step["client"]
          )
          SlideShow.SubProgress(
            100 * step_index / steps_nr,
            step["title"] || fallback_msg
          )
          SlideShow.StageProgress(
            current_stage_percent + (100 / stages.size) * step_index / steps_nr,
            nil
          )
          # use as ' * %1' -> ' * One of the finish steps...' in the SlideShow log
          SlideShow.AppendMessageToInstLog(
            Builtins.sformat(
              _(" * %1"),
              step["title"] || fallback_msg
            )
          )
          orig = Progress.set(false)

          Hooks.run "before_#{step["client"]}"

          WFM.CallFunction(step["client"], ["Write"])

          Hooks.run "after_#{step["client"]}"

          Progress.set(orig)
          # Handle user input during client run
          user_ret = UI.PollInput
          # Aborting...?
          if user_ret == :abort
            return false if Popup.ConfirmAbort(:incomplete)
          # Anything else
          else
            SlideShow.HandleInput(user_ret)
          end
        end
        SlideShow.SubProgress(100, nil)
      end

      true
    end

    def report_messages
      return if Misc.boot_msg.empty?
      return if Mode.autoinst
      # --------------------------------------------------------------
      # Check if there is a message left to display
      # and display it, if necessary

      # Do not call any SCR, it's already closed!
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

    def handle_kexec
      # fate #303395: Use kexec to avoid booting between first and second stage
      # run new kernel via kexec instead of reboot

      # command for reading kernel_params
      cmd = "ls '#{String.Quote(Directory.vardir)}/kexec_done' |tr -d '\n'"
      log.info "Checking flag of successful loading kernel via command #{cmd}"

      out = WFM.Execute(path(".local.bash_output"), cmd)

      expected_output = "#{Directory.vardir}/kexec_done"

      # check output
      if out["stdout"] != expected_output
        log.info "File kexec_done was not found, output: #{out}"
        return
      end

      # HACK: using kexec switch to console 1
      cmd = "chvt 1"
      log.info "Switch to console 1 via command: #{cmd}"
      # switch to console 1
      out = WFM.Execute(path(".local.bash_output"), cmd)
      # check output
      if out["exit"] != 0
        log.error "Switching failed, output: #{out}"
        return
      end

      # waiting s for switching...
      sleep(1)
    end

    def report_hooks
      used_hooks = Hooks.all.select(&:used?)
      failed_hooks = used_hooks.select(&:failed?)

      if !failed_hooks.empty?
        log.error "#{failed_hooks.size} failed hooks found: " \
          "#{failed_hooks.map(&:name).join(", ")}"
      end

      log.info "Hook summary:" unless used_hooks.empty?

      used_hooks.each do |hook|
        log.info "Hook name: #{hook.name}"
        log.info "Hook result: #{hook.succeeded? ? "success" : "failure"}"
        hook.files.each do |file|
          log.info "Hook file: #{file.path}"
          log.info "Hook output: #{file.output}"
        end
      end

      show_used_hooks(used_hooks) unless failed_hooks.empty?
    end

    def show_used_hooks(hooks)
      content = Table(
        Id(:hooks_table),
        Opt(:notify),
        Header("Hook name", "Result", "Output"),
        hooks.map do |hook|
          Item(
            Id(:hook),
            hook.name,
            hook.failed? ? "failure" : "success",
            hook.files.map(&:output).reject(&:empty?).join
          )
        end
      )
      Builtins.y2milestone "Showing the hooks results in UI"
      Popup.LongText(
        "Hooks results",
        content,
        # the width and hight numbers reflect subjective visual appearance of the popup
        80, 5 + hooks.size
      )
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

      text = cmd["stdout"] if cmd["exit"] == 0 && !cmd["stdout"].empty?
      InstError.ShowErrorPopUp(
        _("Installation Error"),
        client_error_text,
        text
      )

      nil
    end

    def setup_wizard
      Wizard.DisableBackButton
      Wizard.DisableNextButton

      Wizard.SetTitleIcon("yast-sysconfig")
    end

    def setup_slide_show
      # Adjust a SlideShow dialog if not configured
      if [nil, {}].include?(SlideShow.GetSetup)
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

      log = _("Creating list of finish scripts to call...")
      SlideShow.SubProgress(0, "")
      SlideShow.StageProgress(0, log)
      SlideShow.AppendMessageToInstLog(log)
    end

    def finish_slide_show
      SlideShow.StageProgress(100, nil)
      SlideShow.AppendMessageToInstLog(_("Finished"))

      return unless @required_to_open_sl_dialog

      log.info "Closing previously opened SlideShow dialog"
      SlideShow.CloseDialog
    end

    def init_packager
      # Used later in 'stages' definition
      # Using empty callbacks that don't break the UI
      PackageCallbacks.RegisterEmptyProgressCallbacks
      Pkg.TargetInitialize(Installation.destdir)
      Pkg.TargetLoad
      PackageCallbacks.RestorePreviousProgressCallbacks
    end

    COPY_FILES_STEPS =
      [
        "autoinst_scripts1",
        "copy_files",
        "copy_systemfiles",
        "live_copy_files",
        "switch_scr"
      ].freeze

    def copy_files_steps
      COPY_FILES_STEPS
    end

    SAVE_CONFIG_STEPS_MINIMAL =
      [
        "save_config",
        "live_save_config",
        "storage",
        "kernel"
      ].freeze

    SAVE_CONFIG_STEPS_FULL =
      [
        "ldconfig",
        "save_config",
        "live_save_config",
        "default_target",
        "desktop",
        "storage",
        "iscsi-client",
        "fcoe-client",
        "kernel",
        "x11",
        "proxy",
        "pkg",
        "scc",
        "driver_update1",
        # bnc #340733
        "system_settings"
      ].freeze

    def save_config_steps
      if ::Installation::MinimalInstallation.instance.enabled?
        SAVE_CONFIG_STEPS_MINIMAL
      else
        SAVE_CONFIG_STEPS_FULL
      end
    end

    SAVE_SETTINGS_STEPS_MINIMAL =
      [
        "yast_inf",
        "autoinst_scripts2",
        "installation_settings"
      ].freeze

    SAVE_SETTINGS_STEPS_FULL =
      [
        "yast_inf",
        "network",
        "firewall_stage1",
        "ntp-client",
        "ssh_settings",
        "remote",
        "save_hw_status",
        "users",
        "autoinst_scripts2",
        "installation_settings",
        "roles",
        "services"
      ].freeze

    def save_settings_steps
      if ::Installation::MinimalInstallation.instance.enabled?
        SAVE_SETTINGS_STEPS_MINIMAL
      else
        SAVE_SETTINGS_STEPS_FULL
      end
    end

    INSTALL_BOOTLOADER_STEPS_MINIMAL =
      [
        "prep_shrink", # ensure that prep partition is small enough for boot sector (bnc#867345)
        "bootloader"
      ].freeze

    def install_bootloader_steps
      if ::Installation::MinimalInstallation.instance.enabled?
        INSTALL_BOOTLOADER_STEPS_MINIMAL
      else
        [
          "prep_shrink", # ensure that prep partition is small enough for boot sector (bnc#867345)
          "cio_ignore", # needs to be run before initrd is created (bsc#933177)
          ProductFeatures.GetBooleanFeature("globals", "enable_kdump") == true ? "kdump" : "",
          "bootloader"
        ]
      end
    end

    def control_stages
      log.info "Using inst_finish steps definition from control file"
      stages = deep_copy(ProductControl.inst_finish)

      # Inst-finish need to be translated (#343783)
      textdom = Ops.get_string(
        ProductControl.productControl,
        "textdomain",
        "control"
      )

      log.info "Inst finish stages before: #{stages}"

      stages.each do |stage|
        label = stage["label"]
        next if label.nil? || label == ""
        loc_label = Builtins.dgettext(textdom, label)
        # if translated
        if !loc_label.nil? && loc_label != "" && loc_label != label
          stage["label"] = loc_label
        end
      end

      log.info "Inst finish stages after: #{stages}"

      stages
    end

    def predefined_stages
      log.info "inst_finish steps definition not found in control file"

      [
        {
          "id"    => "copy_files",
          # progress stage
          "label" => _("Copy files to installed system"),
          "steps" => copy_files_steps,
          "icon"  => "pattern-basis"
        },
        {
          "id"    => "save_config",
          # progress stage
          "label" => _("Save configuration"),
          "steps" => save_config_steps,
          "icon"  => "yast-desktop-select"
        },
        {
          "id"    => "save_settings",
          # progress stage
          "label" => _("Save installation settings"),
          "steps" => save_settings_steps,
          "icon"  => "yast-network"
        },
        # bnc#860089: Save bootloader as late as possible
        # all different (config) files need to be written and copied first
        {
          "id"    => "install_bootloader",
          # progress stage
          "label" => _("Install boot manager"),
          "steps" => install_bootloader_steps,
          "icon"  => "yast-bootloader"
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
            "snapshots",
            "umount"
          ],
          # bnc #438154
          "icon"  => Mode.live_installation ? "yast-live-install-finish" : "yast-scripts"
        }
      ]
    end

    def merge_addon_steps(stages)
      # merge steps from add-on products
      # bnc #438678
      stages[0]["steps"] = WorkflowManager.GetAdditionalFinishSteps("before_chroot") + stages[0]["steps"]
      stages[1]["steps"] = WorkflowManager.GetAdditionalFinishSteps("after_chroot") + stages[1]["steps"]
      stages[3]["steps"].concat(WorkflowManager.GetAdditionalFinishSteps("after_chroot"))
    end

    def run_type
      return @run_type if @run_type

      @run_type = if Mode.update
        :update
      elsif Mode.autoinst
        :autoinst
      elsif Mode.live_installation
        :live_installation
      else
        :installation
      end

      @run_type
    end

    def keep_only_valid_steps(stage)
      steps = stage["steps"].map do |s|
        # some steps are called in live installer only
        next nil if s == "" || s.nil?
        s += "_finish"
        if !WFM.ClientExists(s)
          log.warn "Missing YaST client: #{s}"
          next nil
        end
        log.info "Calling inst_finish script: #{s} (Info)"
        orig = Progress.set(false)
        info = WFM.CallFunction(s, ["Info"])
        Progress.set(orig)
        if info.nil?
          log.error "Client #{s} returned invalid data"
          ReportClientError(
            Builtins.sformat(_("Client %1 returned invalid data."), s)
          )
          next nil
        end
        if info["when"] && !info["when"].include?(run_type) &&
            # special hack for autoupgrade - should be as regular upgrade as possible, scripts are the only exception
            !(Mode.autoupgrade && info["when"].include?(:autoupg))
          next nil
        end
        log.info "inst_finish client %{s} will be called"
        info["client"] = s

        info
      end
      stage["steps"] = steps.compact
    end

    def stages
      return @stages if @stages

      # FIXME: looks like product specific finish steps are not used at all
      stages = if ProductControl.inst_finish.empty?
        predefined_stages
      else
        control_stages
      end

      merge_addon_steps(stages)

      stages.each_with_index do |stage, index|
        SlideShow.SubProgress(
          100 * (index + 1) / stages.size,
          Builtins.sformat(_("Checking stage: %1..."), stage["label"] || stage["id"] || "")
        )
        keep_only_valid_steps(stage)
      end

      log.info "These inst_finish stages will be called:"
      stages.each { |stage| log.info "Stage: #{stage}" }

      stages.delete_if { |s| s["steps"].empty? }

      @stages = stages
    end
  end
end

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

# File: include/installation/inst_inc_second.ycp
# Module: System installation
# Summary: Functions for second stage
# Authors: Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  module InstallationInstIncSecondInclude
    def initialize_installation_inst_inc_second(include_target)
      Yast.import "UI"
      Yast.import "Pkg"

      textdomain "installation"

      Yast.import "FileUtils"
      Yast.import "Popup"
      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "Language"
      Yast.import "Directory"
      Yast.import "WorkflowManager"
      Yast.import "ProductControl"
      Yast.import "Console"
      Yast.import "Keyboard"
      Yast.import "Service"
      Yast.import "Progress"
      Yast.import "Wizard"
      Yast.import "InstData"

      Yast.include include_target, "installation/misc.rb"

      # The order of services is important
      # especially for starting them
      @inst_network_services = ["network", "portmap", "SuSEfirewall2_setup"]
    end

    def AdjustDisabledModules
      if InstData.wizardsteps_disabled_modules == nil
        Builtins.y2error("Disabled modules file not defined")
        return
      end

      if !FileUtils.Exists(InstData.wizardsteps_disabled_modules)
        Builtins.y2milestone(
          "File %1 doesn't exist, skipping...",
          InstData.wizardsteps_disabled_modules
        )
        return
      end

      disabled_modules = Convert.convert(
        SCR.Read(path(".target.ycp"), InstData.wizardsteps_disabled_modules),
        :from => "any",
        :to   => "list <string>"
      )
      if disabled_modules == nil
        Builtins.y2error(
          "Error reading %1",
          InstData.wizardsteps_disabled_modules
        )
        return
      end

      Builtins.foreach(disabled_modules) do |one_module|
        ProductControl.DisableModule(one_module)
      end

      Builtins.y2milestone(
        "Disabled modules set to %1",
        ProductControl.GetDisabledModules
      )

      nil
    end

    def AdjustDisabledProposals
      if InstData.wizardsteps_disabled_proposals == nil
        Builtins.y2error("Disabled proposals file not defined")
        return
      end

      if !FileUtils.Exists(InstData.wizardsteps_disabled_proposals)
        Builtins.y2milestone(
          "File %1 doesn't exist, skipping...",
          InstData.wizardsteps_disabled_proposals
        )
        return
      end

      disabled_proposals = Convert.convert(
        SCR.Read(path(".target.ycp"), InstData.wizardsteps_disabled_proposals),
        :from => "any",
        :to   => "list <string>"
      )
      if disabled_proposals == nil
        Builtins.y2error(
          "Error reading %1",
          InstData.wizardsteps_disabled_proposals
        )
        return
      end

      Builtins.foreach(disabled_proposals) do |one_proposal|
        ProductControl.DisableProposal(one_proposal)
      end

      Builtins.y2milestone(
        "Disabled proposals set to %1",
        ProductControl.GetDisabledProposals
      )

      nil
    end

    def AdjustDisabledSubProposals
      if InstData.wizardsteps_disabled_subproposals == nil
        Builtins.y2error("Disabled subproposals file not defined")
        return
      end

      if !FileUtils.Exists(InstData.wizardsteps_disabled_subproposals)
        Builtins.y2milestone(
          "File %1 doesn't exist, skipping...",
          InstData.wizardsteps_disabled_subproposals
        )
        return
      end

      disabled_subproposals = Convert.convert(
        SCR.Read(
          path(".target.ycp"),
          InstData.wizardsteps_disabled_subproposals
        ),
        :from => "any",
        :to   => "map <string, list <string>>"
      )
      if disabled_subproposals == nil
        Builtins.y2error(
          "Error reading %1",
          InstData.wizardsteps_disabled_subproposals
        )
        return
      end

      Builtins.foreach(disabled_subproposals) do |unique_id, subproposals|
        Builtins.foreach(subproposals) do |one_subproposal|
          ProductControl.DisableSubProposal(unique_id, one_subproposal)
        end
      end

      Builtins.y2milestone(
        "Disabled subproposals set to %1",
        ProductControl.GetDisabledSubProposals
      )

      nil
    end


    def AdjustDisabledItems
      AdjustDisabledModules()
      AdjustDisabledProposals()
      AdjustDisabledSubProposals()

      nil
    end

    # Stores the current status of network services into
    # Installation::reboot_net_settings file
    #
    # @param [Symbol] ret containing either `reboot or anything else
    # @see inst_network_services for list of network services
    def StoreNetworkServices(ret)
      # Store the current status of services
      # bugzilla #258742
      if ret == :reboot
        network_settings = {}
        Builtins.foreach(@inst_network_services) do |one_service|
          Ops.set(
            network_settings,
            one_service,
            Service.Status(one_service) == 0
          )
        end
        Builtins.y2milestone(
          "Storing services status: %1 into %2",
          network_settings,
          Installation.reboot_net_settings
        )
        SCR.Write(
          path(".target.ycp"),
          Installation.reboot_net_settings,
          network_settings
        )
      else
        if FileUtils.Exists(Installation.reboot_net_settings)
          SCR.Execute(path(".target.remove"), Installation.reboot_net_settings)
        end
      end

      nil
    end

    def InitNetworkServices
      Builtins.y2milestone("Initializing network services...")

      # no settings stored
      if !FileUtils.Exists(Installation.reboot_net_settings)
        Builtins.y2milestone(
          "File %1 doesn't exist, skipping InitNetworkServices",
          Installation.reboot_net_settings
        )
        return
      end

      network_settings = Convert.convert(
        SCR.Read(path(".target.ycp"), Installation.reboot_net_settings),
        :from => "any",
        :to   => "map <string, boolean>"
      )
      Builtins.y2milestone("Adjusting services: %1", network_settings)

      # wrong syntax, wrong settings
      if network_settings == nil
        Builtins.y2error(
          "Cannot read stored network services %1",
          SCR.Read(path(".target.string"), Installation.reboot_net_settings)
        )
        return
      end

      start_service = []
      starting_service = []

      # leave just services to be enabled
      # that are not running yet and that also exist
      network_settings = Builtins.filter(network_settings) do |one_service, new_status|
        if new_status != true
          Builtins.y2milestone("Service %1 needn't be started", one_service)
          next false
        end
        service_status = Service.Status(one_service)
        # 0 means running
        if service_status == 0
          Builtins.y2milestone("Service %1 is already running", one_service)
          next false
        end
        # -1 means unknown (which might be correct, package needn't be installed)
        if service_status == -1
          Builtins.y2warning("Service %1 is unknown", one_service)
          next false
        end
        # TRANSLATORS: progress stage, %1 stands for service name
        start_service = Builtins.add(
          start_service,
          Builtins.sformat(_("Start service %1"), one_service)
        )
        # TRANSLATORS: progress stage, %1 stands for service name
        starting_service = Builtins.add(
          starting_service,
          Builtins.sformat(_("Starting service %1..."), one_service)
        )
        true
      end

      if Builtins.size(network_settings) == 0 || network_settings == nil
        Builtins.y2milestone(
          "Nothing to adjust, leaving... %1",
          network_settings
        )
        return
      end

      Progress.New(
        # TRANSLATORS: dialog caption
        _("Adjusting Network Settings"),
        " ",
        Builtins.size(network_settings),
        start_service,
        starting_service,
        # TRANSLATORS: dialog help
        _("Network settings are being adjusted.")
      )
      Wizard.SetTitleIcon("yast-network")

      Progress.NextStage

      # Adjusting services
      Builtins.foreach(network_settings) do |one_service, _new_status|
        ret = Service.Start(one_service)
        Builtins.y2milestone(
          "Starting service %1 returned %2",
          one_service,
          ret
        )
        Progress.NextStage
      end

      Progress.Finish
      Builtins.y2milestone("All network services have been adjusted")

      nil
    end

    def SetUpdateLanguage
      var_file = Ops.add(Directory.vardir, "/language.ycp")
      if FileUtils.Exists(var_file)
        var_map = Convert.to_map(SCR.Read(path(".target.ycp"), var_file))
        lang = Ops.get_string(var_map, "second_stage_language")
        if lang != nil
          Builtins.y2milestone("Setting language to: %1", lang)
          Language.QuickSet(lang)
          Builtins.y2milestone("using %1 for second stage", lang)
        else
          Builtins.y2error(
            "Cannot set language, tmp-file contains: %1",
            var_map
          )
        end
        SCR.Execute(path(".target.remove"), var_file)
      end

      nil
    end

    # Checks whether the second stage installation hasn't been aborted or whether
    # it hasn't failed before. FATE #300422.
    #
    # @return [Symbol] what to do, `next means continue
    def RerunInstallationIfAborted
      # Second stage installation bas been aborted or has failed
      if FileUtils.Exists(Installation.file_inst_aborted) ||
          FileUtils.Exists(Installation.file_inst_failed)
        # popup question (#x1)
        show_error = _(
          "The previous installation has failed.\n" +
            "Would you like it to continue?\n" +
            "\n" +
            "Note: You may have to enter some information again."
        )
        if FileUtils.Exists(Installation.file_inst_aborted)
          # popup question (#x1)
          show_error = _(
            "The previous installation has been aborted.\n" +
              "Would you like it to continue?\n" +
              "\n" +
              "Note: You may have to enter some information again."
          )

          Builtins.y2milestone("Case: aborted")
        else
          Builtins.y2milestone("Case: failed")
        end

        if !Popup.YesNoHeadline(
            # popup headline (#x1)
            _("Starting Installation..."),
            show_error
          )
          Builtins.y2warning(
            "User didn't want to restart the second stage installation..."
          )
          if FileUtils.Exists(Installation.file_inst_aborted)
            SCR.Execute(path(".target.remove"), Installation.file_inst_aborted)
          end
          if FileUtils.Exists(Installation.file_inst_failed)
            SCR.Execute(path(".target.remove"), Installation.file_inst_failed)
          end
          if FileUtils.Exists(Installation.run_yast_at_boot)
            SCR.Execute(path(".target.remove"), Installation.run_yast_at_boot)
          end

          # skipping the second stage
          return :skipped
        end
      end

      # Second stage installation is starting just here

      # creating files in case the installation fails
      # they are removed at the end if everything works well
      Builtins.y2milestone(
        "Creating files for case if installation fails (reset button)"
      )
      # might be left from the previous run
      if FileUtils.Exists(Installation.file_inst_aborted)
        SCR.Execute(path(".target.remove"), Installation.file_inst_aborted)
      end
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("touch %1", Installation.file_inst_failed)
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("touch %1", Installation.run_yast_at_boot)
      )

      :next
    end

    def CleanUpRestartFiles
      if FileUtils.Exists(Installation.reboot_file)
        Builtins.y2milestone("Removing file %1", Installation.reboot_file)
        SCR.Execute(path(".target.remove"), Installation.reboot_file)
      end
      if FileUtils.Exists(Installation.restart_file)
        Builtins.y2milestone("Removing file %1", Installation.restart_file)
        SCR.Execute(path(".target.remove"), Installation.restart_file)
      end
      if FileUtils.Exists(Installation.restart_data_file)
        Builtins.y2milestone("Removing file %1", Installation.restart_data_file)
        SCR.Execute(path(".target.remove"), Installation.restart_data_file)
      end

      nil
    end

    def EnableAutomaticModuleProbing
      WFM.Execute(
        path(".local.bash"),
        "/bin/echo \"/sbin/modprobe\" >/proc/sys/kernel/modprobe"
      )

      nil
    end

    def HandleSecondStageFinishedCorrectly
      # remove /etc/install.inf, not needed any more
      SCR.Execute(path(".target.remove"), "/etc/install.inf")
      if Mode.update
        Builtins.y2milestone("Removing %1", Installation.file_update_mode)
        SCR.Execute(path(".target.remove"), Installation.file_update_mode)
        SCR.Execute(path(".target.remove"), "/var/adm/current_package_descr")
      elsif Mode.live_installation
        Builtins.y2milestone("Removing %1", Installation.file_live_install_mode)
        SCR.Execute(path(".target.remove"), Installation.file_live_install_mode)
      end

      if FileUtils.Exists(Installation.run_yast_at_boot)
        Builtins.y2milestone("Removing %1", Installation.run_yast_at_boot)
        SCR.Execute(path(".target.remove"), Installation.run_yast_at_boot)
      end

      # This file says that the configuration has failed
      # we don't need it anymore
      # FATE #300422
      if FileUtils.Exists(Installation.file_inst_failed)
        Builtins.y2milestone("Removing file %1", Installation.file_inst_failed)
        SCR.Execute(path(".target.remove"), Installation.file_inst_failed)
      end

      # This file has the current step of the workflow to be used
      # for crash recovery during installation. It can be deleted when
      # the installation has been completed.
      if FileUtils.Exists(Installation.current_step)
        Builtins.y2milestone("Removing file %1", Installation.current_step)
        SCR.Execute(path(".target.remove"), Installation.current_step)
      end

      if WFM.ClientExists("product_post")
        WFM.CallFunction("product_post", [Mode.update])
      end

      nil
    end

    def HandleSecondStageAborted
      # removing the current step information
      # installation will be started from the very begining
      if FileUtils.Exists(Installation.current_step)
        Builtins.y2milestone("Removing file %1", Installation.current_step)
        SCR.Execute(path(".target.remove"), Installation.current_step)
      end

      # not to be identified as failed but aborted
      if FileUtils.Exists(Installation.file_inst_failed)
        Builtins.y2milestone("Removing file %1", Installation.file_inst_failed)
        SCR.Execute(path(".target.remove"), Installation.file_inst_failed)
      end

      # creating files saying that YaST will be started after reboot
      # if they don't exist
      Builtins.y2warning(
        "Second Stage Installation has been aborted, creating files %1 and %2",
        Installation.run_yast_at_boot,
        Installation.file_inst_aborted
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("touch %1", Installation.run_yast_at_boot)
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("touch %1", Installation.file_inst_aborted)
      )

      nil
    end

    def PrepareYaSTforRestart(ret)
      # bnc #432005
      # After reboot, YaST will be started (inform user what to do if needed)
      yast_needs_rebooting = false

      # restarting yast, removing files that identify the user-abort or installation-crash
      # bugzilla #222896
      if FileUtils.Exists(Installation.file_inst_aborted)
        SCR.Execute(path(".target.remove"), Installation.file_inst_aborted)
      end
      if FileUtils.Exists(Installation.file_inst_failed)
        SCR.Execute(path(".target.remove"), Installation.file_inst_failed)
      end

      # creating new files to identify restart
      last_step = ProductControl.CurrentStep
      restarting_step = last_step

      if ret == :restart_same_step
        last_step = Ops.subtract(last_step, 1)
        ret = :restart_yast
      end

      if ret == :reboot_same_step
        last_step = Ops.subtract(last_step, 1)
        ret = :reboot
      end

      next_step = Ops.add(last_step, 1)
      Builtins.y2milestone(
        "Creating %1 file with values %2",
        Installation.restart_data_file,
        [next_step, restarting_step]
      )
      SCR.Write(
        path(".target.string"),
        Installation.restart_data_file,
        Builtins.sformat("%1\n%2", next_step, restarting_step)
      )

      if ret == :reboot
        Builtins.y2milestone("Creating %1 file", Installation.reboot_file)
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("touch %1", Installation.reboot_file)
        )
        # bnc #432005
        Builtins.y2milestone("YaST needs rebooting")
        yast_needs_rebooting = true
      elsif ret == :restart_yast
        Builtins.y2milestone("Creating %1 file", Installation.restart_file)
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("touch %1", Installation.restart_file)
        )
      end

      WriteSecondStageRequired(yast_needs_rebooting)

      ret
    end

    def SetSecondStageInstallation
      if !Mode.autoupgrade
        # Detect mode early to be able to setup steps correctly
        if FileUtils.Exists(
            Ops.add(Installation.destdir, Installation.file_update_mode)
          )
          Mode.SetMode("update")
        elsif FileUtils.Exists(
            Ops.add(Installation.destdir, Installation.file_live_install_mode)
          )
          Mode.SetMode("live_installation")
        end
      end

      SetXENExceptions()

      # during update, set the 'update language' for the 2nd stage
      # FATE #300572
      SetUpdateLanguage() if Mode.update

      # Properly setup timezone for continue mode
      Yast.import "Timezone"
      Timezone.Set(Timezone.timezone, true)
      # set only text locale
      Pkg.SetTextLocale(Language.language)

      UI.RecordMacro(Ops.add(Directory.logdir, "/macro_inst_cont.ycp"))

      # Merge control files of additional products and patterns
      listname = Ops.add(
        Ops.add(Installation.destdir, Directory.etcdir),
        "/control_files/order.ycp"
      )
      if FileUtils.Exists(listname)
        files = Convert.convert(
          SCR.Read(path(".target.ycp"), listname),
          :from => "any",
          :to   => "list <string>"
        )

        basedir = Ops.add(
          Ops.add(Installation.destdir, Directory.etcdir),
          "/control_files/"
        )
        files = Builtins.maplist(files) { |one_file| Ops.add(basedir, one_file) }

        WorkflowManager.SetAllUsedControlFiles(files)
        WorkflowManager.SetBaseWorkflow(false)
        WorkflowManager.MergeWorkflows
        WorkflowManager.RedrawWizardSteps
      end

      nil
    end

    def SetLanguageAndEncoding
      Installation.encoding = Console.Restore
      Console.Init
      if Ops.get_boolean(UI.GetDisplayInfo, "HasFullUtf8Support", true)
        Installation.encoding = "UTF-8"
      end

      #//////////////////////////////////////////////////////////
      # activate language settings and console font

      language = Language.language

      UI.SetLanguage(language, Installation.encoding)
      WFM.SetLanguage(language, "UTF-8")

      if !Mode.test
        Keyboard.Set(Keyboard.current_kbd)

        # ncurses calls 'dumpkeys | loadkeys --unicode' in UTF-8 locale
        UI.SetKeyboard
        Builtins.y2milestone(
          "lang: %1, encoding %2",
          language,
          Installation.encoding
        )
      end

      nil
    end
  end
end

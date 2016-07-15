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

# File:	clients/inst_system_analysis.ycp
# Package:	Installation
# Summary:	Installation mode selection, system analysis
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>

require "yast"

module Yast
  class InstSystemAnalysisClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Arch"
      Yast.import "GetInstArgs"
      Yast.import "Hotplug"
      Yast.import "InstData"
      Yast.import "Kernel"
      Yast.import "Packages"
      Yast.import "Popup"
      Yast.import "Product"
      Yast.import "ProductProfile"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Storage"
      Yast.import "StorageControllers"
      Yast.import "StorageDevices"
      Yast.import "Wizard"
      Yast.import "PackageCallbacks"

      Yast.include self, "installation/misc.rb"
      Yast.include self, "packager/storage_include.rb"
      Yast.include self, "packager/load_release_notes.rb"

      if Mode.autoupgrade
        Report.Import(

          "messages" => { "timeout" => 10 },
          "errors"   => { "timeout" => 10 },
          "warnings" => { "timeout" => 10 }

        )
      end

      # This dialog in not interactive
      # always return `back when came from the previous dialog
      if GetInstArgs.going_back
        Storage.ActivateHld(false)
        return :back
      end

      @found_controllers = true

      @packager_initialized = false

      Wizard.SetContents(_("Analyzing the Computer"), Empty(), "", false, false)
      Wizard.SetTitleIcon("yast-controller")

      # Do hardware probing
      #
      # This must happen before submodule descriptions are initialized; module
      # constructors might depend on it.
      # In autoinst mode, this has been called already.

      actions_todo = []
      actions_doing = []
      actions_functions = []

      Builtins.y2milestone("Probing done: %1", Installation.probing_done)
      # skip part of probes as it doesn't change, but some parts (mostly disks
      # that can be activated) need rerun see BNC#865579
      if !Installation.probing_done
        # TRANSLATORS: progress steps in system probing
        if !(Arch.s390 || Arch.board_iseries)
          actions_todo      << _("Probe USB devices")
          actions_doing     << _("Probing USB devices...")
          actions_functions << fun_ref(method(:ActionUSB), "boolean ()")

          actions_todo      << _("Probe FireWire devices")
          actions_doing     << _("Probing FireWire devices...")
          actions_functions << fun_ref(method(:ActionFireWire), "boolean ()")

          actions_todo      << _("Probe floppy disk devices")
          actions_doing     << _("Probing floppy disk devices...")
          actions_functions << fun_ref(method(:ActionFloppyDisks), "boolean ()")
        end

        actions_todo      << _("Probe hard disk controllers")
        actions_doing     << _("Probing hard disk controllers...")
        actions_functions << fun_ref(method(:ActionHHDControllers), "boolean ()")

        actions_todo      << _("Load kernel modules for hard disk controllers")
        actions_doing     << _("Loading kernel modules for hard disk controllers...")
        actions_functions << fun_ref(method(:ActionLoadModules), "boolean ()")

        actions_todo      << _("Probe hard disks")
        actions_doing     << _("Probing hard disks...")
        actions_functions << fun_ref(method(:ActionHDDProbe), "boolean ()")

        WFM.CallFunction("inst_features", [])
      end

      # FATE #302980: Simplified user config during installation
      actions_todo      << _("Search for system files")
      actions_doing     << _("Searching for system files...")
      actions_functions << fun_ref(method(:FilesFromOlderSystems), "boolean ()")

      actions_todo      << _("Initialize software manager")
      actions_doing     << _("Initializing software manager...")
      actions_functions << fun_ref(method(:InitInstallationRepositories), "boolean ()")

      Progress.New(
        # TRANSLATORS: dialog caption
        _("System Probing"),
        " ",
        actions_todo.size,
        actions_todo,
        actions_doing,
        # TRANSLATORS: dialog help
        _("YaST is probing computer hardware and installed systems now.")
      )

      actions_functions.each do |run_function|
        Progress.NextStage
        # Bugzilla #298049
        # Allow to abort the probing
        ui_ret = UI.PollInput
        if ui_ret == :abort
          Builtins.y2milestone("Abort pressed")

          if Popup.ConfirmAbort(:painless)
            Builtins.y2warning("User decided to abort the installation")
            next :abort
          end
        end

        ret = run_function.call
        Builtins.y2milestone("Function %1 returned %2", run_function, ret)
        # Return in case of restart is needed
        return ret if ret == :restart_yast
      end
      Installation.probing_done = true

      # the last step is hidden
      return :abort if ProductProfile.CheckCompliance(nil) == false

      Progress.Finish

      return :abort unless @packager_initialized

      :next
    end

    # Function definitions -->

    # --------------------------------------------------------------
    #				      USB
    # --------------------------------------------------------------
    def ActionUSB
      Hotplug.StartUSB

      true
    end

    # --------------------------------------------------------------
    #				FireWire (ieee1394)
    # --------------------------------------------------------------
    def ActionFireWire
      Hotplug.StartFireWire

      true
    end

    # --------------------------------------------------------------
    #				    Floppy
    # --------------------------------------------------------------
    def ActionFloppyDisks
      StorageDevices.FloppyReady

      true
    end

    # --------------------------------------------------------------
    #			     Hard disk controllers
    # 1. Probe
    # 2. Initialize (module loading)
    # --------------------------------------------------------------
    # In live_eval mode, all modules have been loaded by linuxrc. But
    # they are loaded by StorageControllers::Initialize(). Well, there
    # also was another reason for skipping StorageControllers::Probe ()
    # but nobody seems to remember more.
    # --------------------------------------------------------------
    def ActionHHDControllers
      @found_controllers = Ops.greater_than(StorageControllers.Probe, 0)

      true
    end

    # --------------------------------------------------------------
    # Don't abort or even warn if no storage controllers can be
    # found.  Disks might be detected even without proper knowledge
    # about the controller.  There's a warning below if no disks were
    # found.
    # --------------------------------------------------------------
    def ActionLoadModules
      StorageControllers.Initialize

      true
    end

    # --------------------------------------------------------------
    #				  Hard disks
    # --------------------------------------------------------------
    def ActionHDDProbe
      targetMap = StorageDevices.Probe(true)

      # additonal error when HW was not found
      drivers_info = _(
        "\nCheck 'drivers.suse.com' if you need specific hardware drivers for installation."
      )

      if !ProductFeatures.GetBooleanFeature("globals", "show_drivers_info")
        drivers_info = ""
      end

      if Builtins.size(targetMap) == 0
        if @found_controllers || Arch.s390
          if !(Mode.autoinst || Mode.autoupgrade)
            # pop-up error report
            Report.Error(
              Builtins.sformat(
                _(
                  "No hard disks were found for the installation.\n" \
                    "Please check your hardware!\n" \
                    "%1\n"
                ),
                drivers_info
              )
            )
          else
            Report.Warning(
              _(
                "No hard disks were found for the installation.\n" \
                  "During an automatic installation, they might be detected later.\n" \
                  "(especially on S/390 or iSCSI systems)\n"
              )
            )
          end
        else
          # pop-up error report
          Report.Error(
            Builtins.sformat(
              _(
                "No hard disks and no hard disk controllers were\n" \
                  "found for the installation.\n" \
                  "Check your hardware.\n" \
                  "%1\n"
              ),
              drivers_info
            )
          )
        end

        return false
      end

      true
    end

    def download_and_show_release_notes
      # try on-line release notes first
      WFM.CallFunction("inst_download_release_notes")

      if !InstData.release_notes.empty? ||
          !load_release_notes(Packages.GetBaseSourceID)
        return
      end

      # push button
      Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")

      product_name = Product.short_name || _("Unknown Product")
      InstData.release_notes[product_name] = @media_text
      UI::SetReleaseNotes(product_name => @media_text)
    end

    def InitInstallationRepositories
      # disable callbacks
      PackageCallbacks.RegisterEmptyProgressCallbacks

      ret = true

      Packages.InitializeCatalogs

      if Packages.InitFailed
        # popup message
        Popup.Message(
          _("Failed to initialize the software repositories.\nAborting the installation.")
        )
        ret = false
      else
        @packager_initialized = true
        Packages.InitializeAddOnProducts

        # bnc#886608: Adjusting product name (for &product; macro) right after we
        # initialize libzypp and get the base product name (intentionally not translated)
        UI.SetProductName(Product.name || "SUSE Linux")

        download_and_show_release_notes
      end

      # reregister callbacks
      PackageCallbacks.RestorePreviousProgressCallbacks

      ret
    end

    def FilesFromOlderSystems
      # FATE #300421: Import ssh keys from previous installations
      # FATE #120103: Import Users From Existing Partition
      # FATE #302980: Simplified user config during installation
      #	All needs to be known before configuring users
      # ReReadTargetMap is needed to fix bug #806454
      Storage.ReReadTargetMap()
      # SetPartProposalFirst is needed to fix bug #865579
      Storage.SetPartProposalFirst(true)

      Builtins.y2milestone("PreInstallFunctions -- start --")
      WFM.CallFunction("inst_pre_install", [])
      Builtins.y2milestone("PreInstallFunctions -- end --")

      true
    end
  end
end

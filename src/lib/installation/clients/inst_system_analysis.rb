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
require "y2storage"

module Yast
  class InstSystemAnalysisClient < Client
    include Yast::Logger

    # Custom exception class to indicate the user (or the AutoYaST profile)
    # decided to abort the installation due to a libstorage-ng error
    class AbortError < RuntimeError
    end

    def main
      Yast.import "UI"

      textdomain "installation"

      # Require here to break dependency cycle (bsc#1070996)
      require "autoinstall/activate_callbacks"

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
      Yast.import "Wizard"
      Yast.import "PackageCallbacks"

      Yast.include self, "installation/misc.rb"
      Yast.include self, "packager/storage_include.rb"
      Yast.include self, "packager/load_release_notes.rb"

      # This dialog in not interactive
      # always return `back when came from the previous dialog
      return :back if GetInstArgs.going_back

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
        end

        WFM.CallFunction("inst_features", [])
      end

      actions_todo      << _("Probe hard disks")
      actions_doing     << _("Probing hard disks...")
      actions_functions << fun_ref(method(:ActionHDDProbe), "boolean ()")

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
            return :abort
          end
        end

        begin
          ret = run_function.call
          Builtins.y2milestone("Function %1 returned %2", run_function, ret)
        rescue AbortError
          return :abort
        end

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

    #	USB initialization
    def ActionUSB
      Hotplug.StartUSB

      true
    end

    # FireWire (ieee1394) initialization
    def ActionFireWire
      Hotplug.StartFireWire

      true
    end

    #	Hard disks initialization
    #
    # @raise [AbortError] if an error is found and the installation must
    #   be aborted because of such error
    def ActionHDDProbe
      init_storage
      devicegraph = storage_manager.probed

      # additonal error when HW was not found
      drivers_info = _(
        "\nCheck 'drivers.suse.com' if you need specific hardware drivers for installation."
      )

      if !ProductFeatures.GetBooleanFeature("globals", "show_drivers_info")
        drivers_info = ""
      end

      if devicegraph.empty?
        if Mode.auto
          Report.Warning(
            # TRANSLATORS: Error pop-up
            _(
              "No hard disks were found for the installation.\n" \
              "During an automatic installation, they might be detected later.\n" \
              "(especially on S/390 or iSCSI systems)\n"
            )
          )
        else
          Report.Error(
            Builtins.sformat(
              # TRANSLATORS: Error pop-up
              _(
                "No hard disks were found for the installation.\n" \
                "Please check your hardware!\n" \
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
      end

      # reregister callbacks
      PackageCallbacks.RestorePreviousProgressCallbacks

      ret
    end

    def FilesFromOlderSystems
      # FATE #300421: Import ssh keys from previous installations
      # FATE #120103: Import Users From Existing Partition
      # FATE #302980: Simplified user config during installation
      Builtins.y2milestone("PreInstallFunctions -- start --")
      WFM.CallFunction("inst_pre_install", [])
      Builtins.y2milestone("PreInstallFunctions -- end --")

      true
    end

  private

    # Return the activate callbacks for libstorage-ng
    #
    # When running AutoYaST, it will use a different set of callbacks.
    # Otherwise, it just delegates on yast2-storage-ng which callbacks
    # to use.
    #
    # @return [Storage::ActivateCallbacks,nil] Activate callbacks to use
    #   or +nil+ for default.
    def activate_callbacks
      return nil unless Mode.auto
      Y2Autoinstallation::ActivateCallbacks.new
    end

    # Activates high level devices (RAID, multipath, LVM, encryption...)
    # and (re)probes
    #
    # Reprobing ensures we don't bring bug#806454 back and invalidates cached
    # proposal, so we are also safe from bug#865579.
    #
    # @raise [AbortError] if an error is found and the installation must
    #   be aborted because of such error
    def init_storage
      success = storage_manager.activate(activate_callbacks)
      success &&= storage_manager.probe
      return if success

      log.info "A storage error was raised and the installation must be aborted."
      raise AbortError, "User aborted"
    end

    # @return [Y2Storage::StorageManager]
    def storage_manager
      @storage_manager ||= Y2Storage::StorageManager.instance
    end
  end
end

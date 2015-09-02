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

# File: include/installation/inst_inc_first.ycp
# Module: System installation
# Summary: Functions for first stage
# Authors: Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  module InstallationInstIncFirstInclude
    def initialize_installation_inst_inc_first(include_target)
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Arch"
      Yast.import "Installation"
      Yast.import "Console"
      Yast.import "Language"
      Yast.import "ProductControl"
      Yast.import "Directory"
      Yast.import "Stage"
      Yast.import "FileUtils"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "ProductFeatures"
      Yast.import "AutoinstConfig"
      Yast.import "InstFunctions"

      Yast.include include_target, "installation/misc.rb"
    end

    def InitMouse
      nil
    end

    # Sets inital language and other settings.
    def SetInitialInstallation
      SetXENExceptions()

      Builtins.y2milestone("Adjusting language settings")

      # properly set up initial language
      Installation.encoding = Console.SelectFont(Language.language)
      if Ops.get_boolean(UI.GetDisplayInfo, "HasFullUtf8Support", true)
        Installation.encoding = "UTF-8"
      end

      UI.SetLanguage(Language.language, Installation.encoding)
      WFM.SetLanguage(Language.language, "UTF-8")
      UI.RecordMacro(Ops.add(Directory.logdir, "/macro_inst_initial.ycp"))

      Builtins.y2milestone("Adjusting first stage modules")

      show_addons = ProductFeatures.GetBooleanFeature("globals", "show_addons")
      addons_default = ProductFeatures.GetBooleanFeature(
        "globals",
        "addons_default"
      )
      # default fallback
      show_addons = true if show_addons.nil?
      addons_default = false if addons_default.nil?

      Builtins.y2milestone(
        "Control file definition for add-on, visible: %1, selected: %2",
        show_addons,
        addons_default
      )
      if show_addons
        ProductControl.EnableModule("add-on")
      else
        ProductControl.DisableModule("add-on")
      end
      Installation.add_on_selected = addons_default

      show_online_repositories = ProductFeatures.GetBooleanFeature(
        "globals",
        "show_online_repositories"
      )
      online_repositories_default = ProductFeatures.GetBooleanFeature(
        "globals",
        "online_repositories_default"
      )
      # default fallback
      show_online_repositories = false if show_online_repositories.nil?
      online_repositories_default = true if online_repositories_default.nil?

      Builtins.y2milestone(
        "Control file definition for productsources, visible: %1, selected: %2",
        show_online_repositories,
        online_repositories_default
      )
      if show_online_repositories
        ProductControl.EnableModule("productsources")
      else
        ProductControl.DisableModule("productsources")
      end
      Installation.productsources_selected = online_repositories_default

      Builtins.y2milestone("Disabling second stage modules")
      # First-stage users module will enable them again only if needed
      ProductControl.DisableModule("root")
      ProductControl.DisableModule("user")
      # bnc #401319
      ProductControl.DisableModule("user_non_interactive")
      ProductControl.DisableModule("auth")

      nil
    end

    def InitFirstStageInstallationSystem
      # in the initial stage, there might be some ZYPP data from the
      # previously failed installation
      # @see bugzilla #267763
      if Stage.initial
        zypp_data = ["/var/lib/zypp/cache", "/var/lib/zypp/db"]

        Builtins.foreach(zypp_data) do |zypp_data_item|
          if FileUtils.Exists(zypp_data_item)
            Builtins.y2warning(
              "Directory '%1' exists, removing...",
              String.Quote(zypp_data_item)
            )
            bashcmd = Builtins.sformat("/usr/bin/rm -rf '%1'", zypp_data_item)
            Builtins.y2milestone(
              "Result: %1",
              WFM.Execute(path(".local.bash_output"), bashcmd)
            )
          end
        end
      end

      nil
    end

    # Handle starting distro upgrade from running system
    def SetSystemUpdate
      if FileUtils.Exists(Installation.run_update_file)
        Mode.SetMode("update")

        Builtins.foreach(
          [
            "language", # language already selected
            "disks_activate", # disks activated before running upgrade
            "mode", # always doing update, is already preselected
            "update_partition", # no mounting
            "prepdisk"
          ]
        ) { |m| ProductControl.DisableModule(m) } # disks already mounted, it is dummy in update anyway
      end

      nil
    end

    def HandleSecondStageRequired
      # file name
      run_yast_at_boot = "#{Installation.destdir}/#{Installation.run_yast_at_boot}"

      if InstFunctions.second_stage_required?
        Builtins.y2milestone("Running the second stage is required")
        WFM.Write(path(".local.string"), run_yast_at_boot, "")
        WriteSecondStageRequired(true)
      else
        Builtins.y2milestone("It is not required to run the second stage")
        WFM.Execute(path(".local.remove"), run_yast_at_boot)
        WriteSecondStageRequired(false)
      end
      nil
    end
  end
end

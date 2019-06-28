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

# Module:  installation.ycp
#
# Authors:  Lukas Ocilka <locilka@suse.cz>
#
# Purpose:  Visual speeding-up the installation.
#    This client only initializes the UI
#    and calls the real installation.
#
# $Id$
module Yast
  class InstallationClient < Client
    include Yast::Logger

    def main
      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Stage"
      Yast.import "Report"
      Yast.import "Hooks"
      Yast.import "Linuxrc"
      Yast.import "Mode"
      Yast.import "OSRelease"
      Yast.import "ProductFeatures"
      Yast.import "ProductControl"

      # log the inst-sys identification for easier debugging
      log_os_release

      Hooks.search_path.join!("installation")

      # Initialize the UI
      if ProductFeatures.GetStringFeature("globals", "installation_ui") == "sidebar"
        UI.SetProductLogo(false)
        Wizard.OpenNextBackStepsDialog
      else
        UI.SetProductLogo(true)
        Wizard.OpenLeftTitleNextBackDialog
      end

      Wizard.SetContents(
        # title
        "",
        # contents
        Empty(),
        # help
        "",
        # has back
        false,
        # has next
        false
      )
      if Mode.update
        Wizard.SetDesktopTitleAndIcon("upgrade")
      else
        Wizard.SetDesktopTitleAndIcon("installation")
      end
      Wizard.DisableAbortButton

      @ret = nil

      # Call the real installation
      Builtins.y2milestone("=== installation ===")

      Hooks.run "installation_start"

      # First-stage (initial installation)
      if Stage.initial
        Builtins.y2milestone(
          "Stage::initial -> running inst_worker_initial client"
        )
        @ret = WFM.CallFunction("inst_worker_initial", WFM.Args)

        # Second-stage (initial installation)
      elsif Stage.cont
        Builtins.y2milestone(
          "Stage::cont -> running inst_worker_continue client"
        )
        @ret = WFM.CallFunction("inst_worker_continue", WFM.Args)
      else
        # TRANSLATORS: error message
        Report.Error(_("No workflow defined for this kind of installation."))
      end

      Hooks.run "installation_failure" if @ret == false

      Builtins.y2milestone("Installation ret: %1", @ret)
      Builtins.y2milestone("=== installation ===")

      Hooks.run "installation_finish"

      # Shutdown the UI
      Wizard.CloseDialog

      WFM.CallFunction("disintegrate_all_extensions") if Stage.initial

      deep_copy(@ret)
    end

    # log the system name found in the /etc/os-release file
    # to easily find which system is running in inst-sys
    def log_os_release
      if OSRelease.os_release_exists?
        log.info("System identification: #{OSRelease.ReleaseInformation.inspect}")
      else
        log.warn("Cannot read the OS release file")
      end
    end
  end
end

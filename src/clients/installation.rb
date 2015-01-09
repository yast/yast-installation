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

# Module:	installation.ycp
#
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Purpose:	Visual speeding-up the installation.
#		This client only initializes the UI
#		and calls the real installation.
#
# $Id$
module Yast
  class InstallationClient < Client
    def main
      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Stage"
      Yast.import "Report"
      Yast.import "Hooks"

      Hooks.search_path.join!("installation")

      # Initialize the UI
      UI.SetProductLogo(true);
      Wizard.OpenLeftTitleNextBackDialog
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
      Wizard.SetTitleIcon("yast-inst-mode")
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
  end
end

Yast::InstallationClient.new.main

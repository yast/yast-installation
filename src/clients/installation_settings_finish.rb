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

# File:	clients/installation_settings_finish.ycp
# Package:	Installation
# Summary:	Installation - save settings (used later in second stage, or ...).
#		See bnc #364066, #390930.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class InstallationSettingsFinishClient < Client
    def main
      textdomain "installation"

      Yast.import "ProductControl"
      Yast.import "InstData"
      Yast.import "Mode"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2milestone("starting installation_settings_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        @ret = {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Writing automatic configuration..."
          ),
          # Live Installation has a second stage workflow now (BNC #675516)
          "when"  => [
            :installation,
            :live_installation,
            :update,
            :autoinst
          ]
        }
      elsif @func == "Write"
        Write()
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      deep_copy(@ret)
    end

    def Write
      if ProductControl.GetDisabledModules == nil
        Builtins.y2error("Wrong definition of DisabledModules")
        return
      end

      if InstData.wizardsteps_disabled_modules == nil
        Builtins.y2error("Path to write disabled modules is not defined!")
        return
      end

      Builtins.y2milestone(
        "Writing disabled modules %1 into %2",
        ProductControl.GetDisabledModules,
        InstData.wizardsteps_disabled_modules
      )

      if SCR.Write(
          path(".target.ycp"),
          InstData.wizardsteps_disabled_modules,
          ProductControl.GetDisabledModules
        ) != true
        Builtins.y2error("Cannot write disabled modules")
      end

      Builtins.y2milestone(
        "Writing disabled proposals %1 into %2",
        ProductControl.GetDisabledProposals,
        InstData.wizardsteps_disabled_proposals
      )

      if SCR.Write(
          path(".target.ycp"),
          InstData.wizardsteps_disabled_proposals,
          ProductControl.GetDisabledProposals
        ) != true
        Builtins.y2error("Cannot write disabled proposals")
      end

      Builtins.y2milestone(
        "Writing disabled subproposals %1 into %2",
        ProductControl.GetDisabledSubProposals,
        InstData.wizardsteps_disabled_subproposals
      )

      if SCR.Write(
          path(".target.ycp"),
          InstData.wizardsteps_disabled_subproposals,
          ProductControl.GetDisabledSubProposals
        ) != true
        Builtins.y2error("Cannot write disabled subproposals")
      end

      Builtins.y2milestone("Anyway, successful")

      nil
    end
  end
end

Yast::InstallationSettingsFinishClient.new.main

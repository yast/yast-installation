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

# File: random_finish.ycp
#
# Module: Handle haveged service and preserve the current randomness state
#
# Authors: Lukas Ocilka <locilka@suse.cz>
#
# $Id$

require "installation/minimal_installation"

module Yast
  class RandomFinishClient < Client
    def main
      textdomain "installation"

      Yast.import "FileUtils"
      Yast.import "Service"

      @ret = nil
      @func = ""
      @param = {}

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting random_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        minimal_inst = ::Installation::MinimalInstallation.instance.enabled?
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Enabling random number generator..."
          ),
          "when"  => minimal_inst ? [] :
            [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        @init_path = "/etc/init.d/"
        @init_service = "haveged"

        # The generator of randomness should be always enabled if possible
        if FileUtils.Exists(
            Builtins.sformat("%1/%2", @init_path, @init_service)
          )
          Builtins.y2milestone("Enabling service %1", @init_service)
          @ret = Service.Enable(@init_service)
        else
          Builtins.y2warning(
            "Cannot enable service %1, %2 is not installed",
            @init_service,
            Builtins.sformat("%1/%2", @init_path, @init_service)
          )
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("random_finish finished")

      deep_copy(@ret)
    end

    # Calls a local command and returns if successful
    def LocalCommand(command)
      cmd = Convert.to_map(WFM.Execute(path(".local.bash_output"), command))
      Builtins.y2milestone("Command %1 returned: %2", command, cmd)

      if Ops.get_integer(cmd, "exit", -1) == 0
        return true
      else
        if Ops.get_string(cmd, "stderr", "") != ""
          Builtins.y2error("Error: %1", Ops.get_string(cmd, "stderr", ""))
        end
        return false
      end
    end
  end
end

Yast::RandomFinishClient.new.main

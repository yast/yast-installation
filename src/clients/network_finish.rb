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

# File:
#  network_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class NetworkFinishClient < Client
    def main

      textdomain "installation"

      Yast.import "Installation"
      Yast.import "ModulesConf"
      Yast.import "Arch"
      Yast.import "Linuxrc"
      Yast.import "String"
      Yast.import "NetworkService"
      Yast.import "Lan"

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

      Builtins.y2milestone("starting network_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Saving network configuration..."),
          "when"  => [:installation, :autoinst]
        }
      elsif @func == "Write"

        if Lan.UseNetworkManager
          NetworkService.use_network_manager
        else
          NetworkService.use_wicked
        end

        NetworkService.EnableDisableNow

        # if network running, write network configuration
        # also in case of IPv6 (bnc#477917)
        if NetworkService.isNetworkRunning || NetworkService.isNetworkv6Running
          Builtins.y2milestone("Save network configuration")
          WFM.CallFunction("save_network")
          ModulesConf.RunDepmod(false)
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("network_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::NetworkFinishClient.new.main

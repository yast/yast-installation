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
#  ssh_service_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Author:
#  Bubli <kmachalkova@suse.cz>
#
# $Id: ssh_service_finish.ycp 54888 2009-01-22 11:47:19Z locilka $
#
module Yast
  class SshServiceFinishClient < Client
    def main

      textdomain "installation"

      Yast.import "Linuxrc"
      Yast.import "Service"


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

      Builtins.y2milestone("starting ssh_service_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Enabling SSH service on installed system..."
          ),
          "when"  => Linuxrc.usessh || Linuxrc.vnc ?
            [:installation, :autoinst] :
            []
        }
      elsif @func == "Write"
        Builtins.y2milestone(
          "SSH service will be enabled, this is SSH/VNC installation"
        )
        Service.Enable("sshd")
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("ssh_service_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::SshServiceFinishClient.new.main

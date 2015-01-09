# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2014 Novell, Inc. All Rights Reserved.
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


module Yast
  import "Installation"

  class CloneFinishClient < Client
    def main

      textdomain "installation"

      func = ""

      # Check arguments
      args = WFM.Args
      if args.size > 0 && args[0].is_a?(::String)
        func = args[0]
      end

      Builtins.y2milestone("starting clone_finish")
      Builtins.y2debug("func=%1", func)

      case func
      when "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Generating AutoYaST profile if needed..."
          ),
          "when"  => [:installation]
        }
      when "Write"
        WFM.call("clone_proposal", ["Write"])

        # copy from insts_sys to target system
        if File.exist? "/root/autoinst.xml"
          WFM.Execute(path(".local.bash"), "cp /root/autoinst.xml #{Installation.destdir}/root/autoinst.xml")
        end

        Builtins.y2milestone("clone_finish Write finished")
      else
        raise "unknown function: #{func}"
      end

      return nil
    end
  end
end

Yast::CloneFinishClient.new.main

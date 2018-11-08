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
#  x11_finish.ycp
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
  class X11FinishClient < Client
    def main
      textdomain "installation"

      Yast.import "Installation"
      Yast.import "String"

      Yast.include self, "installation/misc.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if !WFM.Args.empty? &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if WFM.Args.size > 1 &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting x11_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Copying X Window System configuration into system..."
          ),
          "when"  => [:installation, :update, :autoinst]
        }
      elsif @func == "Write"

        # create backup copy from from inst-sys config to be available in installed
        # or updated system copy /etc/X11/XF86Config from inst-sys to
        # [/mnt]/etc/X11/xorg.conf.install
        # ---
        Builtins.y2milestone(
          "Include X11 config [instsys] to installed system: xorg.conf.install"
        )
        @filename = "/etc/X11/xorg.conf"
        WFM.Execute(path(".local.bash"),
          "/bin/cp " + @filename + " '" + String.Quote(Installation.destdir) + @filename + ".install'")
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("x11_finish finished")
      deep_copy(@ret)
    end
  end
end

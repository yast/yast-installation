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

# File:    pre_umount_finish.ycp
#
# Module:  Step of base installation finish (bugzilla #205389)
#
# Authors: Lukas Ocilka <lukas.ocilka@suse.cz>
#
# $Id$
#
module Yast
  class PreUmountFinishClient < Client
    def main
      Yast.import "UI"

      Yast.import "Misc"
      Yast.import "Installation"
      Yast.import "String"

      Yast.include self, "installation/inst_inc_first.rb"

      textdomain "installation"

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

      Builtins.y2milestone("starting pre_umount_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Checking the installed system..."),
          # !Mode::autoinst
          "when"  => [
            :installation,
            :live_installation,
            :update,
            :autoinst
          ]
        }
      elsif @func == "Write"
        # bugzilla #326478
        # some processes might be still running...
        @cmd = Builtins.sformat(
          "fuser -v '%1' 2>&1",
          String.Quote(Installation.destdir)
        )
        @cmd_run = Convert.to_map(WFM.Execute(path(".local.bash_output"), @cmd))

        Builtins.y2milestone(
          "These processes are still running at %1 -> %2",
          Installation.destdir,
          @cmd_run
        )

        if Ops.greater_than(Builtins.size(Misc.boot_msg), 0)
          # just a beep
          SCR.Execute(path(".target.bash"), "/bin/echo -e 'a'")
        end

        # creates or removes the runme_at_boot file (for second stage)
        # according to the current needs
        #
        # Must be called before 'umount'!
        #
        # See FATE #303396
        HandleSecondStageRequired()
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("pre_umount_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::PreUmountFinishClient.new.main

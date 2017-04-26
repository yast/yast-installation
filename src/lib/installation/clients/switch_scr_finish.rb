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
#  switch_scr_finish.ycp
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
  class SwitchScrFinishClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Directory"
      Yast.import "Installation"

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

      Builtins.y2milestone("starting switch_scr_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Moving to installed system..."),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # --------------------------------------------------------------
        #   stop SCR
        #   restart on destination

        Builtins.y2milestone("Stopping SCR")

        WFM.SCRClose(Installation.scr_handle)

        # --------------------------------------------------------------

        Builtins.y2milestone("Re-starting SCR on %1", Installation.destdir)
        Installation.scr_handle = WFM.SCROpen(
          Ops.add(Ops.add("chroot=", Installation.destdir), ":scr"),
          false
        )

        Builtins.y2milestone("new scr_handle: %1", Installation.scr_handle)

        # bugzilla #201058
        # WFM::SCROpen returns negative integer in case of failure
        if Installation.scr_handle.nil? ||
            Ops.less_than(Installation.scr_handle, 0)
          Builtins.y2error("Cannot switch to the system")
          return false
        end

        Installation.scr_destdir = "/"
        WFM.SCRSetDefault(Installation.scr_handle)

        # re-init tmpdir from new SCR !
        Directory.ResetTmpDir

        # bnc #433057
        # Even if SCR switch worked, run a set of some simple tests
        if TestTheNewSCRHandler() != true
          Builtins.y2error("Switched SCR do not work properly.")
          return false
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("switch_scr_finish finished")
      deep_copy(@ret)
    end

    # Check the new SCR, bnc #433057
    #
    # @return [Boolean] whether successful
    def TestTheNewSCR
      Builtins.y2milestone("Running some tests on the new SCR")

      ret_exec = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "TEST=OK; echo ${TEST}")
      )

      if Ops.get_integer(ret_exec, "exit", -1) != 0
        Builtins.y2milestone("SCR::Execute: %1", ret_exec)
        Builtins.y2error("SCR Error")
        return false
      end

      ret_dir = Convert.to_list(SCR.Read(path(".target.dir"), "/"))

      if ret_dir.nil? || ret_dir == []
        Builtins.y2milestone("SCR::Read/dir: %1", ret_dir)
        Builtins.y2error("SCR Error")
        return false
      end

      scr_dir = SCR.Dir(path(".sysconfig"))

      if scr_dir.nil? || scr_dir == []
        Builtins.y2milestone("SCR::Dir: %1", scr_dir)
        Builtins.y2error("SCR Error")
        return false
      end

      Builtins.y2milestone("SCR seems to be OK")
      true
    end

    def CheckFreeSpaceNow
      ret_exec = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "LANG=en_US.UTF-8 /bin/df -h")
      )

      if Ops.get_integer(ret_exec, "exit", -1) != 0
        Builtins.y2error("Cannot find out free space: %1", ret_exec)
      else
        Builtins.y2milestone(
          "Free space: \n%1",
          Builtins.mergestring(
            Builtins.splitstring(Ops.get_string(ret_exec, "stdout", ""), "\\n"),
            "\n"
          )
        )
      end

      nil
    end

    def TestTheNewSCRHandler
      ret = TestTheNewSCR()

      # BNC #460477
      CheckFreeSpaceNow()

      ret
    end
  end
end

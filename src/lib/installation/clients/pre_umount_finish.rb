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
      Yast.import "Pkg"
      Yast.import "Mode"

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

        # Remove content of /run which has been created by the pre/post
        # install scripts while RPM installation and not needed anymore.
        # (bnc#1071745)
        SCR.Execute(path(".target.bash"), "/bin/rm -rf /run/*")

        # Release all sources, they might be still mounted
        Pkg.SourceReleaseAll

        # save all sources and finish target
        # bnc #398315
        Pkg.SourceSaveAll
        Pkg.TargetFinish

        # BNC #692799: Preserve the randomness state before umounting
        preserve_randomness_state

      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("pre_umount_finish finished")
      deep_copy(@ret)
    end

    private

    # Calls a local command and returns if successful
    def LocalCommand(command)
      cmd = Convert.to_map(WFM.Execute(path(".local.bash_output"), command))
      Builtins.y2milestone("Command %1 returned: %2", command, cmd)

      return true if Ops.get_integer(cmd, "exit", -1) == 0

      if Ops.get_string(cmd, "stderr", "") != ""
        Builtins.y2error("Error: %1", Ops.get_string(cmd, "stderr", ""))
      end
      false
    end

    # Reads and returns the current poolsize from /proc.
    # Returns integer size as a string.
    def read_poolsize
      poolsize_path = "/proc/sys/kernel/random/poolsize"

      poolsize = Convert.to_string(
        WFM.Read(path(".local.string"), poolsize_path)
      )

      if poolsize.nil? || poolsize == ""
        Builtins.y2warning(
          "Cannot read poolsize from %1, using the default",
          poolsize_path
        )
        poolsize = "4096"
      else
        poolsize = Builtins.regexpsub(poolsize, "^([[:digit:]]+).*", "\\1")
      end

      Builtins.y2milestone("Using random/poolsize: '%1'", poolsize)
      poolsize
    end

    # Preserves the current randomness state, BNC #692799
    def preserve_randomness_state
      if Mode.update
        Builtins.y2milestone("Not saving current random seed - in update mode")
        return
      end

      Builtins.y2milestone("Saving the current randomness state...")

      service_bin = "/usr/sbin/haveged"
      random_path = "/dev/urandom"
      store_to = Builtins.sformat(
        "%1/var/lib/misc/random-seed",
        Installation.destdir
      )

      @ret = true

      # Copy the current state of random number generator to the installed system
      if LocalCommand(
        Builtins.sformat(
          "dd if='%1' bs=%2 count=1 of='%3'",
          String.Quote(random_path),
          read_poolsize,
          String.Quote(store_to)
        )
      )
        Builtins.y2milestone(
          "State of %1 has been successfully copied to %2",
          random_path,
          store_to
        )
      else
        Builtins.y2milestone(
          "Cannot store %1 state to %2",
          random_path,
          store_to
        )
        @ret = false
      end

      # stop the random number generator service
      Builtins.y2milestone("Stopping %1 service", service_bin)
      LocalCommand(Builtins.sformat("killproc -TERM %1", service_bin))

      nil
    end
  end
end

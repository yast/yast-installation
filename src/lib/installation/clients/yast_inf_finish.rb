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
#  yast_inf_finish.ycp
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
  class YastInfFinishClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Mode"
      Yast.import "Linuxrc"
      Yast.import "AutoinstConfig"
      Yast.import "Language"
      Yast.import "Keyboard"
      Yast.import "Directory"
      Yast.import "String"
      Yast.import "Arch"

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

      Builtins.y2milestone("starting yast_inf_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Writing YaST configuration..."),
          "when"  => [:installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # write boot information for linuxrc
        # collect data for linuxrc, will be written to /etc/yast.inf
        @linuxrc = {}

        # always do hard reboot to ensure that all stuff is initializes
        # correctly. but no reboot message form linuxrc.
        Ops.set(@linuxrc, "Root", "reboot")
        Ops.set(@linuxrc, "RebootMsg", "0")

        Ops.set(@linuxrc, "Root", "kexec") if LoadKexec()

        # Override linuxrc settings in autoinst mode
        if Mode.autoinst
          if AutoinstConfig.ForceBoot
            Ops.set(@linuxrc, "Root", "reboot")
          elsif AutoinstConfig.RebootMsg
            Ops.set(@linuxrc, "RebootMsg", "1")
          elsif AutoinstConfig.Halt
            Ops.set(@linuxrc, "Root", "halt")
          end
        end

        if Ops.get(@linuxrc, "Root", "") == "kexec"
          # flag for inst_finish -> kerel was successful loaded by kexec
          @cmd = "#{"touch \""}#{Directory.vardir}#{"/kexec_done\""}"
          # call command
          WFM.Execute(path(".local.bash_output"), @cmd)
          if !UI.TextMode
            Builtins.y2milestone("Printing message about loading kernel via kexec")
            SCR.Write(
              path(".dev.tty.stderr"),
              _(
                "\n" \
                  "**************************************************************\n" \
                  "\n" \
                  "Loading installed kernel using kexec.\n" \
                  "\n" \
                  "Trying to load installed kernel via kexec instead of rebooting\n" \
                  "Please, wait.\n" \
                  "\n" \
                  "**************************************************************\n" \
                  "\t\t"
              )
            )
          end
        end

        Ops.set(@linuxrc, "Language", Language.language)
        Ops.set(@linuxrc, "Keytable", Keyboard.keymap)

        Linuxrc.WriteYaSTInf(@linuxrc)

        # --------------------------------------------------------------
        # Copy blinux configuration

        InjectFile("/etc/suse-blinux.conf") if Linuxrc.braille
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("yast_inf_finish finished")
      deep_copy(@ret)
    end

    # fate #303395: Use kexec to avoid booting between first and second stage
    # run new kernel via kexec instead of reboot

    def LoadKexec
      # command for reading kernel_params
      cmd = "ls '#{String.Quote(Directory.vardir)}/kernel_params' |tr -d '\n'"
      Builtins.y2milestone("Checking existing file kernel_params via command %1", cmd)

      out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))

      cmd = "#{Directory.vardir}/kernel_params"
      # check output
      if Ops.get_string(out, "stdout", "") != cmd
        Builtins.y2milestone("File kernel_params was not found, output: %1", out)
        return false
      end

      # command for reading kernel_params
      cmd = "cat '#{String.Quote(Directory.vardir)}/kernel_params' |tr -d '\n'"
      Builtins.y2milestone("Reading kernel arguments via command %1", cmd)
      # read data from /var/lib/YaST2/kernel_params
      out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))
      # check output
      if Ops.get(out, "exit") != 0
        Builtins.y2error("Reading kernel arguments failed, output: %1", out)
        return false
      end

      kernel_args = Ops.get_string(out, "stdout", "")
      # check if kernel_params contains any data
      if kernel_args.size < 2
        Builtins.y2error("%1/kernel_params is empty, kernel_params=%2 ", Directory.vardir, kernel_args)
        return false
      end

      # command for finding initrd file
      cmd = "ls #{Directory.vardir}/initrd-* |tr -d '\n'"
      Builtins.y2milestone("Finding initrd file via command: %1", cmd)
      # find inird file
      out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))
      # check output
      if Ops.get(out, "exit") != 0
        Builtins.y2error("Finding initrd file failed, output: %1", out)
        return false
      end

      initrd = Ops.get_string(out, "stdout", "")
      # check if initrd (string) contains any data
      if initrd.size < 2
        Builtins.y2error("initrd was not found: %1", initrd)
        return false
      end

      # command for finding vmlinuz file
      cmd = "ls #{Directory.vardir}/vmlinuz-* |tr -d '\n'"
      Builtins.y2milestone("Finding vmlinuz file via command: %1", cmd)
      # find inird file
      out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))
      # check output
      if Ops.get(out, "exit") != 0
        Builtins.y2error("Finding vmlinuz file failed, output: %1", out)
        return false
      end

      vmlinuz = Ops.get_string(out, "stdout", "")
      # check if initrd (string) contains any data
      if vmlinuz.size < 2
        Builtins.y2error("vmlinuz was not found: %1", vmlinuz)
        return false
      end

      # command for calling kexec
      cmd = Builtins.sformat(
        "kexec -l --command-line='%1' --initrd='%2' '%3'",
        String.Quote(kernel_args),
        String.Quote(initrd),
        String.Quote(vmlinuz)
      )
      Builtins.y2milestone("Calling kexec via command: %1", cmd)

      # call kexec
      out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))
      # check output
      if Ops.get(out, "exit") != 0
        Builtins.y2error("Calling kexec failed, output: %1", out)
        return false
      end

      Builtins.y2milestone("Loading new kernel was succesful")
      true
    end
  end
end

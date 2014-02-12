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
#  save_hw_status_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#

require "installation/minimal_installation"

module Yast
  class SaveHwStatusFinishClient < Client
    def main

      textdomain "installation"

      Yast.import "Mode"
      Yast.import "HwStatus"
      Yast.import "HWConfig"
      Yast.import "Package"

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

      Builtins.y2milestone("starting save_hw_status_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        minimal_inst = ::Installation::MinimalInstallation.instance.enabled?
        return {
          "steps" => 1,
          # progress step title
          "title" => _("Saving hardware configuration..."),
          "when"  => minimal_inst ? [] : [:installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # Package yast2-printer needs to be installed
        if Package.Installed("yast2-printer")
          @parports = Convert.convert(
            SCR.Read(path(".proc.parport.devices")),
            :from => "any",
            :to   => "list <string>"
          )
          if @parports != nil && Ops.greater_than(Builtins.size(@parports), 0)
            HWConfig.SetValue("static-printer", "STARTMODE", "auto")
            HWConfig.SetValue("static-printer", "MODULE", "lp")
          end
        else
          Builtins.y2warning(
            "Package yast2-printer is not installed, skipping static-printer write..."
          )
        end

        # PS/2 mouse on PPC
        @out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "#!/bin/sh\n" +
              "set -e\n" +
              "if test -f /etc/sysconfig/hardware/hwcfg-static-psmouse\n" +
              "then\n" +
              " exit 0\n" +
              "fi\n" +
              "if test -d /proc/device-tree\n" +
              "then\n" +
              "cd /proc/device-tree\n" +
              "if find * -name name -print0 | xargs -0 grep -qw 8042\n" +
              "then\n" +
              "cat > /etc/sysconfig/hardware/hwcfg-static-psmouse <<EOF\n" +
              "MODULE='psmouse'\n" +
              "EOF\n" +
              "fi\n" +
              "fi\n"
          )
        )
        if Ops.get_integer(@out, "exit", 0) != 0
          Builtins.y2error("Error saving PS/2 mouse: %1", @out)
        else
          Builtins.y2milestone("PS/2 mouse saving process returnes: %1", @out)
        end

        Builtins.y2milestone("PS/2 mouse saving process returnes: %1", @out)
        if Mode.update
          # ensure "no" status for all pci and isapnp devices
          HwStatus.Update
        end

        # write "yes" status for known devices (mouse, keyboard, storage, etc.)
        HwStatus.Save
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("save_hw_status_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::SaveHwStatusFinishClient.new.main

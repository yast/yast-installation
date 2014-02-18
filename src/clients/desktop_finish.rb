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
#  desktop_finish.ycp
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
  class DesktopFinishClient < Client
    include Yast::Logger

    def main
      Yast.import "Pkg"

      textdomain "installation"

      Yast.import "DefaultDesktop"
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "ProductFeatures"
      Yast.import "FileUtils"
      Yast.import "String"

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

      Builtins.y2milestone("starting desktop_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        minimal_inst = ::Installation::MinimalInstallation.instance.enabled?
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Initializing default window manager..."
          ),
          "when"  => minimal_inst ? [] : [:installation, :autoinst]
        }
      elsif @func == "Write"
        if !Mode.update
          # GNOME is the fallback desktop
          selected_desktop = DefaultDesktop.Desktop || "gnome"
          Builtins.y2milestone("Selected desktop: %1", selected_desktop)

          desktop_details = DefaultDesktop.GetAllDesktopsMap.fetch(selected_desktop, {})

          default_wm = desktop_details["desktop"]    || ""
          default_dm = desktop_details["logon"]      || ""
          default_cursor = desktop_details["cursor"] || ""

          log.info "Default desktop: #{default_wm}"
          log.info "Default logon manager: #{default_dm}"
          log.info "Default cursor theme: #{default_cursor}"

          SCR.Write(path(".sysconfig.windowmanager.DEFAULT_WM"), default_wm)
          SCR.Write(path(".sysconfig.windowmanager.X_MOUSE_CURSOR"), default_cursor)
          SCR.Write(path(".sysconfig.windowmanager"), nil)

          @dpmng_file = "/etc/sysconfig/displaymanager"
          # Creates an empty sysconfig file if it doesn't exist
          if !FileUtils.Exists(@dpmng_file) &&
              FileUtils.Exists("/usr/bin/touch")
            Builtins.y2milestone(
              "Creating file %1: %2",
              @dpmng_file,
              SCR.Execute(
                path(".target.bash"),
                Builtins.sformat(
                  "/usr/bin/touch '%1'",
                  String.Quote(@dpmng_file)
                )
              )
            )
          end

          # this one should be obsolete nowadays but maybe KDE still uses it
          @dm_shutdown = ProductFeatures.GetStringFeature(
            "globals",
            "displaymanager_shutdown"
          )
          log.info "Logon manager shutdown: #{@dm_shutdown}"
          if @dm_shutdown != nil && @dm_shutdown != ""
            SCR.Write(
              path(".sysconfig.displaymanager.DISPLAYMANAGER_SHUTDOWN"),
              @dm_shutdown
            )
          end

          Builtins.y2milestone(
            "sysconfig/displaymanager/DISPLAYMANAGER=%1",
            default_dm
          )
          SCR.Write(
            path(".sysconfig.displaymanager.DISPLAYMANAGER"),
            default_dm
          )
          SCR.Write(path(".sysconfig.displaymanager"), nil)

          # bnc #431158, patch done by lnussel
          @polkit_default_privs = ProductFeatures.GetStringFeature(
            "globals",
            "polkit_default_privs"
          )
          if @polkit_default_privs != nil && @polkit_default_privs != ""
            Builtins.y2milestone(
              "Writing %1 to POLKIT_DEFAULT_PRIVS",
              @polkit_default_privs
            )
            SCR.Write(
              path(".sysconfig.security.POLKIT_DEFAULT_PRIVS"),
              @polkit_default_privs
            )
            # BNC #440182
            # Flush the SCR cache before calling the script
            SCR.Write(path(".sysconfig.security"), nil)

            @ret2 = Convert.to_map(
              SCR.Execute(
                path(".target.bash_output"),
                # check whether it exists
                "test -x /sbin/set_polkit_default_privs && " +
                  # give some feedback
                  "echo /sbin/set_polkit_default_privs && " +
                  # It's dozens of lines...
                  "/sbin/set_polkit_default_privs | wc -l && " + "echo 'Done'"
              )
            )
            log.info "Command returned: @ret2"
          end
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("desktop_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::DesktopFinishClient.new.main

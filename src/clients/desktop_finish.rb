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
module Yast
  class DesktopFinishClient < Client
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
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Initializing default window manager..."
          ),
          "when"  => [:installation, :autoinst]
        }
      elsif @func == "Write"
        # this detects WM and DM according to selected patterns and
        # installed packages
        if !Mode.update
          @dd_map = DefaultDesktop.GetAllDesktopsMap

          @selected_desktop = DefaultDesktop.Desktop
          Builtins.y2milestone("Selected desktop: %1", @selected_desktop)

          if @selected_desktop == nil || @selected_desktop == ""
            @selected_desktop = "gnome"
          end

          @default_dm = ""
          @default_wm = ""
          @default_cursor = ""

          @desktop_order = []
          @dorder_map = {}

          # build a map $[desktop_id -> desktop_order]
          Builtins.foreach(@dd_map) do |desktop_id, desktop_def|
            @desktop_order = Builtins.add(@desktop_order, desktop_id)
            Ops.set(
              @dorder_map,
              desktop_id,
              Ops.get(desktop_def, "order") != nil ?
                Ops.get_integer(desktop_def, "order", 9999) :
                9999
            )
          end

          # sort the desktops according to their order
          @desktop_order = Builtins.sort(@desktop_order) do |desktop_x, desktop_y|
            Ops.less_than(
              Ops.get(@dorder_map, desktop_x, 9999),
              Ops.get(@dorder_map, desktop_y, 9999)
            )
          end

          # the default one is always the first one
          @desktop_order = Builtins.prepend(
            @desktop_order,
            DefaultDesktop.Desktop
          )
          Builtins.y2milestone("Desktop order: %1", @desktop_order)

          @desktop_found = false

          Builtins.foreach(@desktop_order) do |d|
            raise Break if @desktop_found
            Builtins.y2milestone("Checking desktop: %1", d)
            Builtins.foreach(Ops.get_list(@dd_map, [d, "packages"], [])) do |package|
              if Pkg.IsProvided(package) &&
                  (Pkg.PkgInstalled(package) || Pkg.IsSelected(package))
                Builtins.y2milestone(
                  "Package %1 selected or installed, desktop %2 matches",
                  package,
                  d
                )
                @desktop_found = true

                @default_dm = Ops.get_string(@dd_map, [d, "logon"], "")
                Builtins.y2milestone(
                  "Setting logon manager %1 - package selected",
                  @default_dm
                )

                @default_wm = Ops.get_string(@dd_map, [d, "desktop"], "")
                Builtins.y2milestone(
                  "Setting window manager %1 - package selected",
                  @default_wm
                )

                @default_cursor = Ops.get_string(
                  @dd_map,
                  [d, "cursor"],
                  @default_cursor
                )
                Builtins.y2milestone(
                  "Setting cursor theme %1 - package selected",
                  @default_cursor
                )
              else
                Builtins.y2milestone(
                  "Package %1 for desktop %2 neither selected nor installed, trying next desktop...",
                  package,
                  d
                )
              end
            end
          end

          Builtins.y2milestone("Default desktop: %1", @default_wm)
          Builtins.y2milestone("Default logon manager: %1", @default_dm)
          Builtins.y2milestone("Default cursor theme: %1", @default_cursor)

          SCR.Write(path(".sysconfig.windowmanager.DEFAULT_WM"), @default_wm)
          SCR.Write(
            path(".sysconfig.windowmanager.X_MOUSE_CURSOR"),
            @default_cursor
          )
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
          Builtins.y2milestone("Logon manager shutdown: %1", @dm_shutdown)
          if @dm_shutdown != nil && @dm_shutdown != ""
            SCR.Write(
              path(".sysconfig.displaymanager.DISPLAYMANAGER_SHUTDOWN"),
              @dm_shutdown
            )
          end

          Builtins.y2milestone(
            "sysconfig/displaymanager/DISPLAYMANAGER=%1",
            @default_dm
          )
          SCR.Write(
            path(".sysconfig.displaymanager.DISPLAYMANAGER"),
            @default_dm
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
            Builtins.y2milestone("Command returned: %1", @ret2)
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

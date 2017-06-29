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

require "installation/finish_client"
require "yast2/execute"

Yast.import "DefaultDesktop"
Yast.import "ProductFeatures"
Yast.import "FileUtils"

module Yast
  class DesktopFinishClient < ::Installation::FinishClient
    def initialize
      textdomain "installation"
    end

    def title
      _("Initializing default window manager...")
    end

    def modes
      [:installation, :autoinst]
    end

    def write
      selected_desktop = DefaultDesktop.Desktop
      log.info "Selected desktop: #{selected_desktop}"

      if selected_desktop.nil?
        log.info "no desktop set, skipping."
        return nil
      end

      desktop_map = DefaultDesktop.GetAllDesktopsMap[selected_desktop]
      raise "Selected desktop '#{selected_desktop}' missing in desktops map" unless desktop_map

      log.info "selected desktop #{desktop_map}"

      default_dm = desktop_map["logon"] || ""
      default_wm = desktop_map["desktop"] || ""
      default_cursor = desktop_map["cursor"] || ""

      SCR.Write(path(".sysconfig.windowmanager.DEFAULT_WM"), default_wm)
      SCR.Write(
        path(".sysconfig.windowmanager.X_MOUSE_CURSOR"),
        default_cursor
      )
      SCR.Write(path(".sysconfig.windowmanager"), nil)

      dpmng_file = "/etc/sysconfig/displaymanager"
      # Creates an empty sysconfig file if it doesn't exist
      if !FileUtils.Exists(dpmng_file) &&
          FileUtils.Exists("/usr/bin/touch")
        log.info "Creating file #{dpmng_file}"
        Yast::Execute.on_target("/usr/bin/touch", dpmng_file)
      end

      SCR.Write(
        path(".sysconfig.displaymanager.DISPLAYMANAGER"),
        default_dm
      )
      SCR.Write(path(".sysconfig.displaymanager"), nil)

      # bnc #431158, patch done by lnussel
      polkit_default_privs = ProductFeatures.GetStringFeature(
        "globals",
        "polkit_default_privs"
      )
      if !polkit_default_privs.nil? && polkit_default_privs != ""
        Builtins.y2milestone(
          "Writing %1 to POLKIT_DEFAULT_PRIVS",
          polkit_default_privs
        )
        SCR.Write(
          path(".sysconfig.security.POLKIT_DEFAULT_PRIVS"),
          polkit_default_privs
        )
        # BNC #440182
        # Flush the SCR cache before calling the script
        SCR.Write(path(".sysconfig.security"), nil)

        ret2 = SCR.Execute(
          path(".target.bash_output"),
          # check whether it exists
          # give some feedback
          # It's dozens of lines...
          "test -x /sbin/set_polkit_default_privs && " \
            "echo /sbin/set_polkit_default_privs && " \
            "/sbin/set_polkit_default_privs | wc -l && " \
            "echo 'Done'"
        )
        log.info "Command returned: #{ret2}"
      end

      nil
    end
  end
end

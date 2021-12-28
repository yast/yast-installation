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

      default_wm = desktop_map["desktop"] || ""
      default_cursor = desktop_map["cursor"] || ""

      SCR.Write(path(".sysconfig.windowmanager.DEFAULT_WM"), default_wm)
      SCR.Write(
        path(".sysconfig.windowmanager.X_MOUSE_CURSOR"),
        default_cursor
      )
      SCR.Write(path(".sysconfig.windowmanager"), nil)

      nil
    end
  end
end

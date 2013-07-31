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

# File:	clients/inst_restore_settings
# Package:	Installation
# Summary:	Restore settings after restart during 2nd-stage installation
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
module Yast
  class InstRestoreSettingsClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "GetInstArgs"
      Yast.import "Service"
      Yast.import "NetworkInterfaces"
      Yast.import "SuSEFirewall"

      return :back if GetInstArgs.going_back

      Builtins.foreach(["network"]) do |service|
        if Service.Enabled(service) && Service.Status(service) != 0
          # TRANSLATORS: busy message
          UI.OpenDialog(
            Label(Builtins.sformat(_("Starting service %1..."), service))
          )

          # This might take a lot of time if case of DHCP, for instance
          Service.RunInitScriptWithTimeOut(service, "start")

          UI.CloseDialog
        end
      end

      NetworkInterfaces.Read

      # bugzilla #282871
      # If firewall is enabled, only the initial script is started.
      # Start also the final firewall phase.
      Service.Start("SuSEfirewall2_setup") if SuSEFirewall.IsEnabled


      :auto 

      # EOF
    end
  end
end

Yast::InstRestoreSettingsClient.new.main

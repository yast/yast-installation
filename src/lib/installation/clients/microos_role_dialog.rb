# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2024 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "cwm/dialog"
require "installation/widgets/ntp_server"
require "installation/dhcp_ntp_servers"

module Installation
  # This library provides a simple dialog for setting
  # the admin role specific settings:
  #   - the NTP server names
  class AdminRoleDialog < CWM::Dialog
    include DhcpNtpServers

    def initialize
      textdomain "installation"

      Yast.import "Product"
      Yast.import "ProductFeatures"
      super
    end

    #
    # The dialog title
    #
    # @return [String] the title
    #
    def title
      # TRANSLATORS: dialog title
      _("NTP Configuration")
    end

    def contents
      return @content if @content

      @content = HSquash(
        MinWidth(50,
          # preselect the servers from the DHCP response
          Installation::Widgets::NtpServer.new(ntp_servers))
      )
    end
  end
end

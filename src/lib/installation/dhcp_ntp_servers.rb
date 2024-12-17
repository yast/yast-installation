# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
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

module Installation
  # This module provides a functionality for reading the NTP servers
  module DhcpNtpServers
    #
    # List of NTP servers from DHCP
    #
    # @return [Array<String>] List of servers (IP or host names), empty if not provided
    #
    def dhcp_ntp_servers
      Yast.import "Lan"

      Yast::Lan.dhcp_ntp_servers
    end

    #
    # Propose the NTP servers from the DHCP response, fallback to a random
    # machine from the ntp.org pool if enabled in control.xml.
    #
    # @return [Array<String>] proposed NTP servers, empty if nothing suitable found
    #
    def ntp_servers
      # TODO: use Yast::NtpClient.ntp_conf if configured
      # to better handle going back
      servers = dhcp_ntp_servers
      servers = ntp_fallback if servers.empty?

      servers
    end

    #
    # The fallback servers for NTP configuration
    #
    # @return [Array<String>] the fallback servers, empty if disabled in control.xml
    #
    def ntp_fallback
      Yast.import "ProductFeatures"
      require "y2network/ntp_server"

      # propose the fallback when enabled in control file
      return [] unless Yast::ProductFeatures.GetBooleanFeature("globals", "default_ntp_setup")

      default_servers = Y2Network::NtpServer.default_servers
      return [] if default_servers.empty?

      [default_servers.sample.hostname]
    end
  end
end

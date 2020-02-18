# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC
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
require "y2network/ntp_server"

module Installation
  module Dialogs
    # Simple dialog for settings the NTP server names
    class NtpSetup < CWM::Dialog
      def initialize
        textdomain "installation"

        Yast.import "Lan"
        Yast.import "LanItems"
        Yast.import "Product"
        Yast.import "ProductFeatures"

        super
      end

      # The dialog title
      #
      # @return [String] the title
      def title
        # TRANSLATORS: dialog title
        _("NTP Setup")
      end

      def contents
        return @content if @content

        @content = HSquash(
          MinWidth(
            50,
            # preselect the servers from the DHCP response
            Widgets::NtpServer.new(ntp_servers)
          )
        )
      end

    private

      # Propose the NTP servers from the DHCP response, fallback to a random
      # machine from the ntp.org pool if enabled in control.xml.
      #
      # @return [Array<String>] proposed NTP servers, empty if nothing suitable found
      def ntp_servers
        # TODO: use Yast::NtpClient.ntp_conf if configured
        # to better handle going back
        servers = dhcp_ntp_servers
        servers = [ntp_fallback.hostname] if servers.empty? && default_ntp_setup_enabled?

        servers
      end

      # List of NTP servers from DHCP
      #
      # @return [Array<String>] List of servers (IP or host names), empty if not provided
      def dhcp_ntp_servers
        # When proposing NTP servers we need to know
        #
        #   1) list of (dhcp) interfaces
        #   2) network service in use
        #
        # We can either use networking submodule for network service handling and get list of
        # interfaces e.g. using a bash command or initialize whole networking module.
        Yast::Lan.ReadWithCacheNoGUI

        Yast::LanItems.dhcp_ntp_servers.values.flatten.uniq
      end

      # Whether the a default (fallback) NTP setup is enabled in the control.xml
      #
      # @return [Boolean]
      def default_ntp_setup_enabled?
        Yast::ProductFeatures.GetBooleanFeature("globals", "default_ntp_setup")
      end

      # The fallback servers for NTP configuration
      #
      # It propose a random server from the default pool
      #
      # @return [Y2Network::NtpServer] the fallback server
      def ntp_fallback
        Y2Network::NtpServer.default_servers.sample
      end
    end
  end
end

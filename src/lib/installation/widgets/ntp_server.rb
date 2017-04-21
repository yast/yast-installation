# encoding: utf-8

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
require "installation/system_role"
require "cwm/widget"

Yast.import "CWM"
Yast.import "Popup"
Yast.import "Label"
Yast.import "IP"
Yast.import "Hostname"

module Installation
  module Widgets
    # This widget is responsible of validating and storing the NTP server to use.
    class NtpServer < CWM::InputField
      # @return [Array<String>] List of default servers
      attr_reader :default_servers

      # Constructor
      #
      # @params default_servers [Array<String>] List of servers
      def initialize(default_servers = [])
        @default_servers = default_servers
      end

      # intentional no translation for CaaSP
      #
      # @return [String] Widget's label
      def label
        "NTP Servers"
      end

      # Store the value of the input field if validates
      def store
        role["ntp_servers"] = servers
      end

      # Initializes the widget's value
      def init
        saved_servers = role["ntp_servers"] || default_servers
        self.value = saved_servers.join(" ")
      end

      NOT_VALID_SERVERS_MESSAGE = "Not valid location for the NTP servers:\n%{servers}" \
        "\n\nPlease, enter a valid IP or Hostname".freeze
      # Validate input
      #
      # * All specified IPs or hostnames should be valid
      # * If no server is specified, ask the user whether proceed with installation or not
      #
      # @return [Boolean] true if value is valid; false otherwise.
      def validate
        return skip_ntp_server? if servers.empty?
        invalid_servers = servers.reject { |v| Yast::IP.Check(v) || Yast::Hostname.CheckFQ(v) }
        return true if invalid_servers.empty?
        Yast::Popup.Error(
          format(NOT_VALID_SERVERS_MESSAGE, servers: invalid_servers.join(", "))
        )

        false
      end

    private

      # Parse the widget's value an return the potential list of hostnames/addresses
      #
      # @return [Array<String>] List of hostnames/addresses
      def servers
        value.tr(",", " ").split(" ")
      end

      # Check if the user wants to intentionally skip the NTP server configuration
      #
      # @return [Boolean] true if user wants to skip it; false otherwise.
      def skip_ntp_server?
        Yast::Popup.AnyQuestion(
          "NTP Servers",
          # TRANSLATORS: error message for invalid ntp server name/address
          "You have not configured an NTP server. This may lead to\n" \
          "your cluster not functioning properly or at all.\n" \
          "Proceed with caution and at your own risk.\n\n" \
          "Would you like to continue with the installation?",
          Yast::Label.YesButton,
          Yast::Label.NoButton,
          :yes
        )
      end

      # Return the dashboard role
      def role
        ::Installation::SystemRole.find("dashboard_role")
      end
    end
  end
end

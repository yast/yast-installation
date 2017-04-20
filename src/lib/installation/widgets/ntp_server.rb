require "yast"
require "installation/system_role"
require "uri"

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
      def label
        "NTP Servers"
      end

      # Store the value of the input field if validates
      def store
        role["ntp_servers"] = servers
      end

      # Initializes the widget's value
      def init
        saved_servers =
          if role["ntp_servers"] && !role["ntp_servers"].empty?
            role["ntp_servers"]
          else
            default_servers
          end
        self.value = saved_servers.join(" ")
      end

      # Validate input
      #
      # * All specified IPs or hostnames should be valid
      # * If no server is specified, ask the user whether proceed with installation or not
      #
      # @return [Boolean] true if value is valid; false otherwise.
      def validate
        return skip_ntp_server? if servers.empty?
        return true if servers.all? { |v| Yast::IP.Check(v) || Yast::Hostname.CheckFQ(v) }
        Yast::Popup.Error(
          # TRANSLATORS: error message for invalid administration node location
          _("Not valid location for the NTP servers, " \
            "please enter a valid IP or Hostname")
        )

        false
      end

    private

      # Parses the widget's value an return the potential list of hostnames/addresses
      #
      # @return [Array<String>] List of hostnames/addresses
      def servers
        value.tr(",", " ").split(" ")
      end

      # Determine if the user wants to intentionally skip the NTP server configuration
      #
      # @return [Boolean] true if user wants to skip it; false otherwise.
      def skip_ntp_server?
        Yast::Popup.AnyQuestion(
          _("NTP Server"),
          # TRANSLATORS: error message for invalid ntp server name/address
          _("You have not configured an NTP server. This may lead to\n" \
            "your cluster not functioning properly or at all.\n" \
            "Proceed with caution and at your own risk.\n\n" \
            "Would you like to continue with the installation?"),
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

    # NTP Server widget placeholder
    class NtpServerPlace < CWM::ReplacePoint
      def initialize(default_servers = [])
        @ntp_server = NtpServer.new(default_servers)
        @empty = CWM::Empty.new("no_ntp_server")
        super(id: "ntp_server_placeholder", widget: @empty)
      end

      # Show the NtpServer widget
      def show
        replace(@ntp_server)
      end

      # Hide the NtpServer widget
      def hide
        replace(@empty)
      end
    end
  end
end

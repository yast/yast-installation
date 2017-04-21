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

require "uri"
require "users/widgets"
require "y2country/widgets"
require "ui/widgets"
require "tune/widgets"
require "registration/widgets/registration_code"

require "installation/widgets/overview"
require "installation/widgets/hiding_place"
require "installation/widgets/system_role"
require "installation/widgets/ntp_server"
require "installation/services"

module Installation
  # This library provides a simple dialog for setting
  # - the password for the system administrator (root)
  # - the keyboard layout
  # This dialog does not write the password to the system,
  # only stores it in UsersSimple module,
  # to be written during inst_finish.
  class InstCaspOverview
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      Yast.import "UI"
      Yast.import "Language"
      Yast.import "Mode"
      Yast.import "CWM"
      Yast.import "Popup"
      Yast.import "Pkg"
      Yast.import "InstShowInfo"
      Yast.import "SlpService"

      textdomain "installation"

      # Simplified work-flow do not contain language proposal, but have software one.
      # So avoid false positive detection of language change
      Yast::Pkg.SetPackageLocale(Yast::Language.language)

      # We do not need to create a wizard dialog in installation, but it's
      # helpful when testing all manually on a running system
      Yast::Wizard.CreateDialog if separate_wizard_needed?

      # show the Beta warning if it exists
      Yast::InstShowInfo.show_info_txt(INFO_FILE) if File.exist?(INFO_FILE)

      ret = nil
      loop do
        ret = Yast::CWM.show(
          content,
          # Title for installation overview dialog
          caption:      _("Installation Overview"),
          # Button label: start the installation
          next_button:  _("Install"),
          # do not show abort and back button
          abort_button: "",
          back_button:  ""
        )

        # Currently no other return value is expected, behavior can
        # be unpredictable if something else is received - raise
        # RuntimeError
        raise "Unexpected return value" if ret != :next

        # do software proposal
        d = Yast::WFM.CallFunction("software_proposal",
          [
            "MakeProposal",
            { "simple_mode" => true }
          ])
        # report problems with sofware proposal
        if [:blocker, :fatal].include?(d["warning_level"])
          # %s is a problem description
          Yast::Popup.Error(
            _("Software proposal failed. Cannot proceed with installation.\n%s") % d["warning"]
          )
        # continue only if confirmed
        elsif Yast::WFM.CallFunction("inst_doit", []) == :next
          break
        end
      end

      add_casp_services

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      ret
    end

  private

    # location of the info.txt file (containing the Beta warning)
    INFO_FILE = "/info.txt".freeze

    # Specific services that needs to be enabled on CAaSP see (FATE#321738)
    # It is additional services to the ones defined for role.
    # It is caasp only services and for generic approach systemd-presets should be used.
    # In this case it is not used, due to some problems with cloud services.
    CASP_SERVICES = ["sshd", "cloud-init-local", "cloud-init", "cloud-config",
                     "cloud-final", "issue-generator", "issue-add-ssh-keys"].freeze
    def add_casp_services
      ::Installation::Services.enabled.concat(CASP_SERVICES)
    end

    def quadrant_layout(upper_left:, lower_left:, upper_right:, lower_right:)
      HBox(
        HWeight(
          6,
          VBox(
            VSpacing(2),
            VWeight(5, upper_left),
            VWeight(5, lower_left)
          )
        ),
        HSpacing(3),
        HWeight(
          4,
          VBox(
            VSpacing(2),
            VWeight(5, upper_right),
            VWeight(5, lower_right)
          )
        )
      )
    end

    # Returns a pair with UI widget-set for the dialog and widgets that can
    # block installation
    def content
      controller_node = Installation::Widgets::HidingPlace.new(Installation::Widgets::ControllerNode.new)
      ntp_server = Installation::Widgets::HidingPlace.new(Installation::Widgets::NtpServer.new(ntp_servers))

      kdump_overview = Installation::Widgets::Overview.new(client: "kdump_proposal")
      bootloader_overview = Installation::Widgets::Overview.new(client: "bootloader_proposal", redraw: [kdump_overview])

      quadrant_layout(
        upper_left:  VBox(
          ::Registration::Widgets::RegistrationCode.new,
          ::Users::PasswordWidget.new(little_space: true),
          # use english us as default keyboard layout
          ::Y2Country::Widgets::KeyboardSelectionCombo.new("english-us")
        ),
        lower_left:  VBox(
          Installation::Widgets::SystemRole.new(controller_node, ntp_server),
          controller_node,
          ntp_server,
          Tune::Widgets::SystemInformation.new
        ),
        upper_right: VBox(
          Installation::Widgets::Overview.new(client: "partitions_proposal", redraw: [bootloader_overview]),
          bootloader_overview
        ),
        lower_right: VBox(
          Installation::Widgets::Overview.new(client: "network_proposal"),
          kdump_overview
        )
      )
    end

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Yast::Mode.normal
    end

    # Regexp to extract the URL from a SLP URL
    # For instance, match 1 for "service:ntp://ntp.suse.de:123,65535"
    # will be "ntp://ntp.suse.de:123"
    SERVICE_REGEXP = %r{\Aservice:(ntp://[^,]+)}
    # SLP identifier for NTP
    NTP_SLP_SERVICE = "ntp".freeze
    # Discover NTP servers through SLP
    #
    # @return [Array<String>] NTP server names
    def ntp_servers
      Yast::SlpService.all(NTP_SLP_SERVICE).each_with_object([]) do |service, servers|
        url = service.slp_url[SERVICE_REGEXP, 1]
        begin
          host = URI(url).host
        rescue URI::InvalidURIError, ArgumentError
          log.warn "#{url.inspect} is not a valid URI"
        else
          servers << host if host
        end
      end
    end
  end
end

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
require "cwm/dialog"

Yast.import "Hostname"
Yast.import "Mode"

module Installation
  module Dialogs
    # Dialog for security proposal configuration
    class Security < CWM::Dialog
      def initialize(settings)
        textdomain "installation"

        @settings = settings
      end

      def title
        _("Security Configuration")
      end

      def contents
        # lazy require to avoid circular dependency on firewall
        require "y2firewall/widgets/proposal"

        VBox(
          Frame(
            _("Firewall and SSH service"),
            HSquash(
              MarginBox(
                0.5,
                0.5,
                VBox(
                  Widgets::FirewallSSHProposal.new(@settings)
                )
              )
            )
          ),
          Frame(
            _("PolicyKit"),
            MarginBox(
              0.5,
              0.5,
              PolkitDefaultPriv.new(@settings)
            )
          )
        )
      end

      def abort_button
        ""
      end

      def back_button
        # do not show back button when running on running system. See CWM::Dialog.back_button
        Yast::Mode.installation ? nil : ""
      end

      def next_button
        Yast::Mode.installation ? Yast::Label.OKButton : Yast::Label.FinishButton
      end

      def disable_buttons
        [:abort]
      end

    protected

      # Hostname of the current system.
      #
      # Getting the hostname is sometimes a little bit slow, so the value is
      # cached to be reused in every dialog redraw
      #
      # @return [String]
      def hostname
        @hostname ||= Yast::Hostname.CurrentHostname
      end

      def should_open_dialog?
        true
      end
    end

    class PolkitDefaultPriv < CWM::ComboBox
      def initialize(settings)
        textdomain "installation"

        @settings = settings
      end

      def label
        _("PolicyKit Default Priviledges")
      end

      def items
        @settings.human_polkit_priviledges.to_a
      end

      def help
        _(
          "<p>SUSE ships with three sets of default privilege " \
          "settings. These are as follows:<br><ul>" \
          "<li>\"restrictive\": conservative settings that " \
          "require the root user password for a lot of actions" \
          " and disable certain actions completely for remote " \
          "users.</li>" \
          "<li>\"standard\": balanced settings that restrict " \
          "sensitive actions to require root authentication " \
          "but allow less dangerous operations for regular " \
          "logged in users.</li>" \
          "<li>\"easy\": settings that are focused on ease " \
          "of use. This sacrifices security to some degree " \
          "to allow a more seamless user experience without" \
          " interruptions in the workflow due to password " \
          "prompts.</li></ul><br>" \
          "The \"default\" is to keep value empty and it will be" \
          "assigned automatically.</p>"
        )
      end

      def init
        self.value = @settings.polkit_default_proviledges || "default"
      end

      def store
        res = value == "default" ? nil : value
        @settings.polkit_default_proviledges = res
      end
    end
  end
end

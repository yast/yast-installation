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
  end
end

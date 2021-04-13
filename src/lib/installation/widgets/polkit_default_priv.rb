# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC
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

require "cwm/common_widgets"
require "installation/security_settings"

module Installation
  module Widgets
    class PolkitDefaultPriv < CWM::ComboBox
      def initialize(settings)
        textdomain "installation"

        @settings = settings
      end

      def label
        _("PolicyKit Default Privileges")
      end

      def items
        @settings.human_polkit_privileges.to_a
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
        self.value = @settings.polkit_default_privileges.to_s
      end

      def store
        @settings.polkit_default_privileges = value.empty? ? nil : value
      end
    end
  end
end

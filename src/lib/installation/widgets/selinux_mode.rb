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

require "yast"
require "cwm/common_widgets"

module Installation
  module Widgets
    # Widget to set SELinux mode
    class SelinuxMode < CWM::ComboBox
      def initialize(settings)
        textdomain "installation"

        @settings = settings
      end

      def label
        # TRANSLATORS: SELinu Mode just SELinux is already content of frame.
        _("Mode")
      end

      def items
        @settings.selinux_config.modes.map { |m| [m.id.to_s, m.to_human_string] }
      end

      def init
        self.value = @settings.selinux_config.mode.id.to_s
      end

      def store
        @settings.selinux_config.mode = value.to_sym
      end

      def help
        _(
          "<p>Sets default SELinux mode. Modes are: <ul>" \
          "<li><b>Enforcing</b> the state that enforces SELinux security policy. "\
          "Access is denied to users and programs unless permitted by " \
          "SELinux security policy rules. All denial messages are logged.</li> "\
          "<b>Permissive</b> is a diagnostic state. The security policy rules are " \
          "not enforced, but SELinux sends denial messages to a log file.</li>" \
          "<b>Disabled</b> SELinux does not enforce a security policy.</li></ul></p>"
        )
      end
    end
  end
end

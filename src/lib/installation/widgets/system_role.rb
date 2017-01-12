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
require "cwm/widget"

module Installation
  module Widgets
    # TODO: steal / refactor Installation::SelectSystemRole
    # from src/lib/installation/select_system_role.rb
    class SystemRole < CWM::ComboBox
      def initialize
        textdomain "installation"
      end

      def label
        _("System Role")
      end

      def items
        [
          # FIXME: still hardcoding for easier testing
          ["foo", _("Adminstration Dashboard")],
          ["bar", _("Worker")],
          ["baz", _("Plain System")],
          ["qux", _("FIXME use real data")]
        ]
      end
    end
  end
end

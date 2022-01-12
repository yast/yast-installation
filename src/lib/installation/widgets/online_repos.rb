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
require "cwm/widget"

module Installation
  module Widgets
    # sets flag if online repositories dialog should be shown
    class OnlineRepos < CWM::PushButton
      def initialize
        super
        textdomain "installation"
      end

      def label
        # TRANSLATORS: Push button label
        _("Configure Online Repositories")
      end

      def handle
        Yast::WFM.CallFunction("inst_productsources", [{ "script_called_from_another" => true }])

        :redraw
      end
    end
  end
end

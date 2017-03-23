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
require "yast2/execute"

module Installation
  module SystemRoleHandlers
    # Implement finish handler for the "dashboard" role
    class DashboardRoleFinish
      # Path to the activation script
      ACTIVATION_SCRIPT_PATH = "/usr/share/caasp-container-manifests/activate.sh".freeze

      # Run the activation script
      def run
        Yast::Execute.on_target(ACTIVATION_SCRIPT_PATH)
      end
    end
  end
end

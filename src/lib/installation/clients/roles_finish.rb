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

require "installation/finish_client"
require "installation/system_role"

module Installation
  module Clients
    # This is a step of base installation finish and is responsible of write the
    # specific configuration for the current system role.
    #
    # It has been added for CaaSP Roles (FATE#321754) and currently only
    # the 'worker_role' has an special behavior.
    class RolesFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Writing specific role configuration  ...")
      end

      # Finish installation for the current role
      def write
        SystemRole.finish
      end
    end
  end
end

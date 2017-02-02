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
require "installation/widgets/system_role"
require "installation/cfa/salt"

module Installation
  module Clients
    class RolesFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Writing specific role configuration  ...")
      end

      def write
        log.info("The current role is: #{current_role}")
        if current_role == "worker_role"
          master_conf = ::Installation::CFA::MinionMasterConf.new
          begin
            master_conf.load
          rescue Errno::ENOENT
            log.info("Fail does not exist, will be created")
            raise unless Yast::Stage.initial
          end
          log.info("The controller node for this worker role is: #{master}")
          master_conf.master = master
          master_conf.save
        end
      end

    private

      # Obtains the current role from the role selection widget
      def current_role
        ::Installation::Widgets::SystemRole.original_role_id
      end

      # Obtains the controller node location from the controller node widget
      def master
        ::Installation::Widgets::ControllerNode.location
      end
    end
  end
end

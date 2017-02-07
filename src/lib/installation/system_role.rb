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

Yast.import "ProductControl"

module Installation
  class SystemRole
    include Singleton
    include Yast::Logger

    attr_accessor :selected, :options

    def initialize
      @roles = Yast::ProductControl.productControl.fetch("system_roles", [])
      @selected = nil
      @options = {}
    end

    def select(role_id, role_options = {})
      @selected = role_id
      @options  = role_options
    end

    def all
      @roles
    end

    def features
      all.find { |r| r["id"] == selected }
    end

    def services
      all.find { |r| r["id"] == selected  }["services"] || []
    end

    def adapt_services
      to_enable = services.map { |s| s["name"] }

      log.info "enable for #{selected} these services: #{to_enable.inspect}"

      Installation::Services.enabled = to_enable
    end

    def installation_finish
      case selected
      when nil,""
        log.info("There is no role selected, nothing to do.")
      when "worker_role"
        master_conf = CFA::MinionMasterConf.new
        begin
          master_conf.load
        rescue Errno::ENOENT
          log.info("The minion master.conf file does not exist, it will be created")
        end
        log.info("The controller node for this worker role is: #{master}")
        master_conf.master = master
        master_conf.save
      else
        log.info("No special behavior for role: #{selected}")
      end
    end
  end
end

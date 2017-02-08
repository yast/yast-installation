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
Yast.import "ProductFeatures"

module Installation
  class SystemRole
    include Yast::Logger

    attr_accessor :id, :label, :description, :services, :options

    def initialize(id, label, description, services, options = {})
      @id          = id
      @label       = label
      @description = description
      @services    = services || []
      @options     = options
    end

    class << self

      attr_reader :current_role

      # Return an array with all the role ids
      #
      # @return [Array<String>] array with all the role ids
      def ids
        all.keys
      end

      def all
        return @roles if @roles

        @roles = raw_roles.each_with_object({}) do |raw_role, entries|
          entries[raw_role["id"]] = from_control(raw_role)
        end
      end

      # Read the roles from the control file
      def raw_roles
        @raw_roles ||= Yast::ProductControl.productControl.fetch("system_roles", [])
      end

      # @return [Hash<SystemRole>]
      def roles
        all.values
      end

      def select(role_id)
        @current_role = find(role_id)
      end

      def current
        @current_role ? @current_role.id : nil
      end

      def find(role_id)
        all[role_id]
      end

      def from_control(raw_role)
        id = raw_role["id"]
        default_args =
          [
            id,
            Yast::ProductControl.GetTranslatedText(id),
            Yast::ProductControl.GetTranslatedText("#{id}_description"),
            raw_role["services"]
          ]

        new(*default_args)
      end

      def finish(role_id)
        class_name_role = role_id.split("_").map { |s| s.capitalize }.join
        handler = "::Installation::SystemRoleHandlers::#{class_name_role}Finish"

        begin
          Object.const_get(handler).run
        rescue NameError, LoadError
          log.info("There is no special finisher for #{role_id}")
        end
      end
    end

    def option(*args)
      key, value = args
      case args.size
      when 0
        raise ArgumentError, "Missing key argument"
      when 1
        @options[key]
      when 2
        @options[key] = value
      else
        raise ArgumentError, "Too many arguments, only key and/or value are supported"
      end
    end

    def adapt_services
      to_enable = services.map { |s| s["name"] }

      log.info "enable for #{id} these services: #{to_enable.inspect}"

      Installation::Services.enabled = to_enable
    end

    NON_OVERLAY_ATTRIBUTES = [
      "additional_dialogs",
      "id",
      "services"
    ].freeze

    private_constant :NON_OVERLAY_ATTRIBUTES

    def overlay_features
      features = self.class.raw_roles.find { |r| r["id"] == id }.dup

      NON_OVERLAY_ATTRIBUTES.each { |a| features.delete(a) }
      Yast::ProductFeatures.SetOverlay(features)
    end
  end

  module SystemRoleHandlers
    class WorkerRoleFinish
      def self.run
        role = SystemRole.find("worker_role")
        master_conf = CFA::MinionMasterConf.new
        master = role.option("controller_node")
        begin
          master_conf.load
        rescue Errno::ENOENT
          log.info("The minion master.conf file does not exist, it will be created")
        end
        log.info("The controller node for this worker role is: #{master}")
        master_conf.master = master
        master_conf.save
      end
    end
  end
end

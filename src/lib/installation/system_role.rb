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
require "installation/system_roles/handlers"

Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  class SystemRole
    include Yast::Logger

    attr_accessor :id, :label, :description, :services

    def initialize(id:, label: id, description: nil, services: [])
      @id          = id
      @label       = label
      @description = description
      @services    = services
      @options     = {}
    end

    class << self

      attr_reader :current_role

      # Return an array with all the role ids
      #
      # @return [Array<String>] array with all the role ids
      def ids
        all.keys
      end

      # Initializes and maintains a map with the id of the roles and
      # SystemRole objects with the roles defined in the control file.
      #
      # @return [Hash<String => SystemRole>]
      def all
        return @roles if @roles

        @roles = raw_roles.each_with_object({}) do |raw_role, entries|
          entries[raw_role["id"]] = from_control(raw_role)
        end
      end

      # Reads the roles from the control file
      def raw_roles
        @raw_roles ||= Yast::ProductControl.productControl.fetch("system_roles", [])
      end

      # Returns an array with all the SystemRole objects
      #
      # @return [Array<SystemRole>]
      def roles
        all.values
      end

      # Establish as the current role the one given
      #
      # @param [String] role id selected
      # @return [SystemRole] the role selected
      def select(role_id)
        @current_role = find(role_id)
      end

      # Returns the current role's id
      #
      # @return [String, nil] current role's id
      def current
        @current_role ? @current_role.id : nil
      end

      # Returns the SystemRole object for the specific role id
      #
      # @param [String] role id
      # @return [SystemRole, nil]
      def find(role_id)
        all[role_id]
      end

      # Creates SystemRole instances based from a role's hash definition
      def from_control(raw_role)
        id = raw_role["id"]

        new(
          id: id,
          label: Yast::ProductControl.GetTranslatedText(id),
          description: Yast::ProductControl.GetTranslatedText("#{id}_description"),
          services: raw_role["services"]
        )
      end

      # Given a role, it runs a a special finish handler for it if exists
      #
      # @param [String] role id
      def finish(role_id)
        if !role_id
          log.info("There is no role selected so nothing to do")
          return
        end

        class_name_role = role_id.split("_").map { |s| s.capitalize }.join
        handler = "::Installation::SystemRoleHandlers::#{class_name_role}Finish"

        begin
          Object.const_get(handler).run
        rescue NameError, LoadError
          log.info("There is no special finisher for #{role_id}")
        end
      end
    end

    def [](key)
      @options[key]
    end

    def []=(key, value)
      @options[key] = value
    end

    # Enables the role services defined in the control file
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

    # Overlays the product features for this role with the configuration
    # obtained from the control file
    def overlay_features
      features = self.class.raw_roles.find { |r| r["id"] == id }.dup

      NON_OVERLAY_ATTRIBUTES.each { |a| features.delete(a) }
      Yast::ProductFeatures.SetOverlay(features)
    end
  end
end

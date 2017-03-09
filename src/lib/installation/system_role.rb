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
require "installation/services"
require "installation/system_roles/handlers"

Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  # This class fetchs and stores the roles declared in the installation control
  # file. It works as a storage for them and for the role selected during the
  # installation.
  class SystemRole
    include Yast::Logger
    extend Forwardable

    # This is the id or name of the role and used as reference to the role
    #
    # @return [String]
    attr_accessor :id
    # The label is usually translated and shoule be a short word more
    # descriptive than the id.
    #
    # @return [String]
    attr_accessor :label
    # It descripts the main capabilities of the role and it is also usually
    # translated  because it is used for description and/or for help in some
    # cases.
    #
    # @return [String, nil]
    attr_accessor :description

    # All the special attributes for a given role are delegated to @options
    def_delegators :@options, :[], :[]=

    # Constructor
    #
    # Only the id, label and description are allowed to be initialized other
    # options have to be set explicitly.
    #
    # @example SystemRole with 'services' and a 'controller node' defined
    #   @role = SystemRole.new(id: "test_role")
    #   @role["services"] = { "name" => "salt-minion" }
    #   @role["controller_node"] = "salt"
    #
    # @param id [String] role id or name
    # @param label [String] it uses the id as label if not given
    # @param description [String]
    def initialize(id:, label: id, description: nil)
      @id          = id
      @label       = label
      @description = description
      @options     = {}
    end

    class << self
      # @return [SystemRole, nil] returns the current role
      attr_reader :current_role

      # Returns an array with all the role ids
      #
      # @example
      #   SystemRole.ids #=> ["role_one", "role_two"]
      #
      # @return [Array<String>] array with all the role ids; empty if no roles
      def ids
        all.keys
      end

      # returns if roles should set default or have no role preselected
      def default?
        !all.values.first["no_default"]
      end

      # Initializes and maintains a map with the id of the roles and
      # SystemRole objects with the roles defined in the control file.
      #
      # @return [Hash<String, SystemRole>]
      def all
        return @roles if @roles

        @roles = raw_roles.each_with_object({}) do |raw_role, entries|
          entries[raw_role["id"]] = from_control(raw_role)
        end
      end

      # Fetchs the roles from the control file and returns them as they are.
      #
      # @example
      #   SystemRole.raw_roles #=> [{ "id" => "role_one" }]
      #
      # @return [Array<Hash>] returns an empty array if no roles defined
      def raw_roles
        @raw_roles ||= Yast::ProductControl.productControl.fetch("system_roles", []) || []
      end

      # Returns an array with all the SystemRole objects
      #
      # @return [Array<SystemRole>] retuns an empty array if no roles defined
      def roles
        all.values
      end

      # Establish as the current role the one given as parameter.
      #
      # @param role_id [String] role to be used as current
      # @return [SystemRole] the object corresponding to the selected role
      # @see current
      def select(role_id)
        @current_role = find(role_id)
      end

      # Returns the current role id
      #
      # @return [String, nil] current role's id
      def current
        @current_role ? @current_role.id : nil
      end

      # Returns the SystemRole object for the specific role id.
      #
      # @param role_id [String]
      # @return [SystemRole, nil]
      def find(role_id)
        all[role_id]
      end

      # Creates a SystemRole instance for the given role (in raw format).
      #
      # @param raw_role [Hash] role definition
      # @return [SystemRole]
      def from_control(raw_role)
        id = raw_role["id"]

        role =
          new(
            id:          id,
            label:       Yast::ProductControl.GetTranslatedText(id),
            description: Yast::ProductControl.GetTranslatedText("#{id}_description")
          )

        role["services"] = raw_role["services"] || []
        role["no_default"] = raw_role["no_default"] || false

        role
      end

      # It runs a special finish handler for the current role if exists
      def finish
        if !current
          log.info("There is no role selected so nothing to do")
          return
        end

        class_name_role = current.split("_").map(&:capitalize).join
        handler = "::Installation::SystemRoleHandlers::#{class_name_role}Finish"

        if Object.const_defined?(handler)
          Object.const_get(handler).run
        else
          log.info("There is no special finisher for #{current}")
        end
      end
    end

    # Enables the role services defined in the control file
    #
    # @return [Array] the list of services to be enable
    def adapt_services
      return [] if !self["services"]

      to_enable = self["services"].map { |s| s["name"] }

      log.info "enable for #{id} these services: #{to_enable.inspect}"

      Installation::Services.enabled = to_enable
    end

    NON_OVERLAY_ATTRIBUTES = [
      "additional_dialogs",
      "id",
      "no_default",
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

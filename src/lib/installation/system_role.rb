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
require "installation/system_role_handlers_runner"

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

    # Order of role.
    # @return [Integer]
    attr_reader :order

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
    # @param order [String, nil] string representation of order or default if nil passed
    def initialize(id:, order:, label: id, description: nil)
      @id          = id
      @label       = label
      @description = description
      @options     = {}
      @order = order.to_i
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
        all.map(&:id)
      end

      # returns if roles should set default or have no role preselected
      def default?
        !all.first["no_default"]
      end

      # Returns an array with all the SystemRole objects sorted according to order
      #
      # @return [Hash<String, SystemRole>]
      def all
        return @roles  if @roles

        @roles = raw_roles.map { |r| from_control(r) }
        @roles.sort_by!(&:order)
      end

      # Clears roles cache
      def clear
        @roles = nil
      end

      # Fetchs the roles from the control file and returns them as they are.
      #
      # @example
      #   SystemRole.raw_roles #=> [{ "id" => "role_one" }]
      #
      # @return [Array<Hash>] returns an empty array if no roles defined
      def raw_roles
        Yast::ProductControl.system_roles
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
        all.find { |r| r.id == role_id }
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
            order:       raw_role["order"],
            label:       Yast::ProductControl.GetTranslatedText(id),
            description: Yast::ProductControl.GetTranslatedText("#{id}_description")
          )

        role["additional_dialogs"] = raw_role["additional_dialogs"]
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
        SystemRoleHandlersRunner.new.finish(current)
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
      "services",
      "order"
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

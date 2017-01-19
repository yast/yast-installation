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
require "installation/services"

Yast.import "ProductControl"
Yast.import "ProductFeatures"


module Installation
  module Widgets
    # TODO: steal / refactor Installation::SelectSystemRole
    # from src/lib/installation/select_system_role.rb
    class SystemRole < CWM::ComboBox
      class << self
        # once the user selects a role, remember it in case they come back
        attr_accessor :original_role_id
      end

      def initialize
        textdomain "installation"
      end

      def label
        Yast::ProductControl.GetTranslatedText("roles_caption")
      end

      def opt
        [:hstretch]
      end

      def init
        self.class.original_role_id ||= roles_attributes.first[:id]
        self.value = self.class.original_role_id
      end

      def items
        roles_description.map do |attr|
          [attr[:id], attr[:label]]
        end
      end

      def help
        Yast::ProductControl.GetTranslatedText("roles_help") + "\n\n"
          roles_description.map { |r| r[:label] + "\n\n" + r[:description] + "\n\n\n"}
      end

      NON_OVERLAY_ATTRIBUTES = [
        "additional_dialogs",
        "id"
      ].freeze
      private_constant :NON_OVERLAY_ATTRIBUTES


      def store
        log.info "Applying system role '#{value}'"
        features = raw_roles.find { |r| r["id"] == value }
        features = features.dup
        NON_OVERLAY_ATTRIBUTES.each { |a| features.delete(a) }
        Yast::ProductFeatures.SetOverlay(features)
        adapt_services
        self.class.original_role_id = value
      end


    private

      def raw_roles
        @raw_roles ||= Yast::ProductControl.productControl.fetch("system_roles", [])
      end

      def roles_description
        @roles_description ||= raw_roles.map do |r|
          id = r["id"]

          {
            id:          id,
            label:       Yast::ProductControl.GetTranslatedText(id),
            description: Yast::ProductControl.GetTranslatedText(id + "_description")
          }
        end
      end

      def adapt_services
        services = raw_roles.find { |r| r["id"] == role_id }["services"]
        services ||= []

        to_enable = services.map { |s| s["name"] }
        log.info "enable for #{role_id} these services: #{to_enable.inspect}"

        Installation::Services.enabled = to_enable
      end
    end
  end
end

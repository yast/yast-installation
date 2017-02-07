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
require "installation/custom_patterns"

Yast.import "DefaultDesktop"
Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  module Widgets
    class DashboardURL < CWM::InputField
      def label
        # intentional no translation for CAASP
        "Dashboard URL"
      end

      def store
        # TODO: implement it together with init and some validation
      end
    end

    class DashboardPlace < CWM::ReplacePoint
      def initialize
        @dashboard = DashboardURL.new
        @empty = CWM::Empty.new("no_dashboard")
        super(widget: @empty)
      end

      def show
        replace(@dashboard)
      end

      def hide
        replace(@empty)
      end
    end

    module SystemRoleReader
      def label
        Yast::ProductControl.GetTranslatedText("roles_caption")
      end

      def items
        roles_description.map do |attr|
          [attr[:id], attr[:label]]
        end
      end

      def help
        Yast::ProductControl.GetTranslatedText("roles_help") + "\n\n" +
          roles_description.map { |r| r[:label] + "\n\n" + r[:description] }.join("\n\n\n")
      end

      NON_OVERLAY_ATTRIBUTES = [
        "additional_dialogs",
        "id"
      ].freeze
      private_constant :NON_OVERLAY_ATTRIBUTES

      def init
        self.class.original_role_id ||= roles_description.first[:id]
        self.value = self.class.original_role_id
      end

      def store
        log.info "Applying system role '#{value}'"
        features = raw_roles.find { |r| r["id"] == value }
        features = features.dup
        NON_OVERLAY_ATTRIBUTES.each { |a| features.delete(a) }
        Yast::ProductFeatures.SetOverlay(features)
        adapt_services
        self.class.original_role_id = value
      end

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
        services = raw_roles.find { |r| r["id"] == value }["services"]
        services ||= []

        to_enable = services.map { |s| s["name"] }
        log.info "enable for #{value} these services: #{to_enable.inspect}"

        Installation::Services.enabled = to_enable
      end
    end

    # CaaSP specialized role widget
    class SystemRole < CWM::ComboBox
      class << self
        # once the user selects a role, remember it in case they come back
        attr_accessor :original_role_id
      end

      include SystemRoleReader

      def initialize(dashboard_widget)
        textdomain "installation"
        @dashboard_widget = dashboard_widget
      end

      def opt
        [:hstretch, :notify]
      end

      alias_method :init_orig, :init
      def init
        init_orig
        handle
      end

      def handle
        if value == "worker_role"
          @dashboard_widget.show
        else
          @dashboard_widget.hide
        end

        nil
      end
    end

    class SystemRolesRadioButtons < CWM::RadioButtons
      class << self
        # once the user selects a role, remember it in case they come back
        attr_accessor :original_role_id
      end

      include SystemRoleReader

      alias_method :store_orig, :store
      def store
        # set flag to show custom patterns only if custom role selected
        CustomPatterns.show = value == "custom"
        store_orig
        # force reset of Default Desktop, because it is cached and when going
        # forward and backward, it can be changed
        Yast::DefaultDesktop.ForceReinit
      end
    end
  end
end

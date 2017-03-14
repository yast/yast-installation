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
require "installation/system_role"

Yast.import "DefaultDesktop"
Yast.import "ProductControl"
Yast.import "IP"
Yast.import "Hostname"

module Installation
  module Widgets
    # This widget is responsible of validate and store the introduced location
    # which must be a valid IP or FQDN.
    class ControllerNode < CWM::InputField
      def label
        # intentional no translation for CAASP
        "Controller Node"
      end

      # It stores the value of the input field if validates
      #
      # @see #validate
      def store
        role["controller_node"] = value
      end

      # The input field is initialized with previous stored value
      def init
        self.value = role["controller_node"]
      end

      # It returns true if the value is a valid IP or a valid FQDN, if not it
      # displays a popup error.
      #
      # @return [Boolean] true if valid IP or FQDN
      def validate
        return true if Yast::IP.Check(value) || Yast::Hostname.CheckFQ(value)

        Yast::Popup.Error(
          # TRANSLATORS: error message for invalid controller node location
          _("Not valid location for the controller node, " \
          "please enter a valid IP or Hostname")
        )

        false
      end

    private

      def role
        ::Installation::SystemRole.find("worker_role")
      end
    end

    class ControllerNodePlace < CWM::ReplacePoint
      def initialize
        @controller_node = ControllerNode.new
        @empty = CWM::Empty.new("no_controller")
        super(widget: @empty)
      end

      def show
        replace(@controller_node)
      end

      def hide
        replace(@empty)
      end
    end

    module SystemRoleReader
      def default
        ::Installation::SystemRole.default? ? ::Installation::SystemRole.ids.first : nil
      end

      def init
        self.value = ::Installation::SystemRole.current || default
      end

      def label
        Yast::ProductControl.GetTranslatedText("roles_caption")
      end

      def items
        ::Installation::SystemRole.all.map do |role|
          [role.id, role.label]
        end
      end

      def help
        Yast::ProductControl.GetTranslatedText("roles_help") + "\n\n" + roles_help_text
      end

      def store
        log.info "Applying system role '#{value}'"
        role = ::Installation::SystemRole.select(value)

        role.overlay_features
        role.adapt_services
      end

    private

      def roles_help_text
        ::Installation::SystemRole.all.map { |r| "#{r.label}\n\n#{r.description}" }.join("\n\n\n")
      end
    end

    # CaaSP specialized role widget
    class SystemRole < CWM::ComboBox
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
      include SystemRoleReader

      alias_method :store_orig, :store
      def store
        # set flag to show custom patterns only if custom role selected
        CustomPatterns.show = value == "custom"
        store_orig

        if value == "custom"
          # for custom role do not use any desktop
          Yast::DefaultDesktop.SetDesktop(nil)
        else
          # force reset of Default Desktop, because it is cached and when going
          # forward and backward, it can be changed
          Yast::DefaultDesktop.ForceReinit
        end
      end
    end
  end
end

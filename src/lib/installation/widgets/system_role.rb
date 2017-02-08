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
require "installation/system_role"

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
        role.option("controller_node", value)
      end

      # The input field is initialized with previous stored value
      def init
        self.value = role.option("controller_node")
      end

      # If the value is not a valid IP or a valid FQDN it displays a popup
      # error and returns false, in other case it just returns true.
      #
      # @return <Boolean> false if not a valid IP or FQDN; true otherwise
      def validate
        unless Yast::IP.Check(value) || Yast::Hostname.CheckFQ(value)
          Yast::Popup.Error(
            # TRANSLATORS: error message for invalid controller node location
            _("Not valid location for the controller node, " \
            "please enter a valid IP or Hostname")
          )
          return false
        end

        true
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

    class SystemRole < CWM::ComboBox
      def initialize(controller_node_widget)
        textdomain "installation"
        @controller_node_widget = controller_node_widget
      end

      def label
        Yast::ProductControl.GetTranslatedText("roles_caption")
      end

      def opt
        [:hstretch, :notify]
      end

      def init
        self.value = ::Installation::SystemRole.current
        handle
      end

      def handle
        if value == "worker_role"
          @controller_node_widget.show
        else
          @controller_node_widget.hide
        end

        nil
      end

      def items
        ::Installation::SystemRole.roles.map do |role|
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
        ::Installation::SystemRole.roles.map do |role|
          role.label + "\n\n" + role.description
        end.join("\n\n\n")
      end
    end
  end
end

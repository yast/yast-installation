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

Yast.import "HTML"

module Installation
  module Widgets
    # Common methods for system roles widgets
    #
    # @see Installation::Widgets::SystemRole
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
        "<p>" + Yast::ProductControl.GetTranslatedText("roles_help") + "</p>\n" + roles_help_text
      end

      def store
        log.info "Applying system role '#{value}'"
        role = ::Installation::SystemRole.select(value)

        role.overlay_features
        role.adapt_services
      end

    private

      def roles_help_text
        ::Installation::SystemRole.all.map do |role|
          "<p>#{Yast::HTML.Heading(role.label)}\n\n#{role.description}</p>"
        end.join("\n")
      end
    end
  end
end

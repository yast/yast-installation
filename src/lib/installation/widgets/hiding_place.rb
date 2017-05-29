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
require "installation/system_role"

module Installation
  module Widgets
    # This class offers a placeholder that to hide/show a given widget
    class HidingPlace < CWM::ReplacePoint
      # Constructor
      #
      # @param main_widget [CWM::AbstractWidget]
      def initialize(main_widget)
        @main_widget = main_widget
        @empty = CWM::Empty.new("no_#{main_widget.widget_id}_placeholder")
        super(id: "#{main_widget.widget_id}_placeholder", widget: @empty)
      end

      # Show the main widget
      def show
        replace(main_widget)
        main_widget.value = @main_widget_value if @main_widget_value
      end

      # Hide the main widget
      def hide
        @main_widget_value = main_widget.value
        replace(empty)
      end

      # Save the main widget value
      def store
        @main_widget_value = main_widget.value
        super
      end

    private

      # @return [CWM::AbstractWidget] main widget
      attr_reader :main_widget
      # @return [Empty] Empty widget placeholder
      attr_reader :empty
    end
  end
end

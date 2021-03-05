# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

module Installation
  module Console
    # base class for the configuration menu plugins
    class MenuPlugin
      extend Yast::Logger

      # when a new subclass is defined this code gets executed
      def self.inherited(subclass)
        # collect instances of all subclasses
        log.info("Found new plugin class: #{subclass}")
        plugins << subclass.new
      end

      # the collected plugin objects
      def self.plugins
        @plugins ||= []
      end

      # get widgets for all plugins
      def self.widgets
        plugins.sort_by! { |p| [p.order, p.class.to_s] }
        plugins.map(&:widget).reject(&:nil?)
      end

      # return a widget do display
      # @return [CWM::Widget] the widget
      def widget
        nil
      end

      # define the display order (in ascending order),
      # if the order value is same than it sorts by the class name
      # @return [Integer] the order
      def order
        100
      end
    end
  end
end

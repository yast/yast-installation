# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "English"
require "yast"
require "cwm/widget"

Yast.import "UI"

module Installation
  module Widgets
    # A CWM button for starting the installer configuration dialog
    class ConsoleButton < CWM::PushButton
      # constructor
      # @param focused_widget [CWM::Widget,nil] widget which should have
      # the initial focus
      def initialize(focused_widget = nil)
        textdomain "installation"
        @focus = focused_widget
      end

      def init
        # set the focus (only in text mode, in GUI the focus does not change
        # after displaying the button)
        @focus.focus if @focus && Yast::UI.TextMode
      end

      def label
        # use an hamburger icon to make the button as small as possible
        "☰"
      end

      def handle
        require "installation/console/menu"
        ::Installation::Console::Menu.new.run
        # ignore the console menu result, force refreshing the dialog
        # to activate possible changes
        :redraw
      end
    end
  end
end

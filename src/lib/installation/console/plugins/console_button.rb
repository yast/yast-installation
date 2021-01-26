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

require "cwm"
require "installation/console/menu_plugin"

module Installation
  module Console
    module Plugins
      # define a button for starting the command line console
      class ConsoleButton < CWM::PushButton
        def initialize
          textdomain "installation"
        end

        def label
          _("Expert Console...")
        end

        def handle
          require "installation/console"
          ::Installation::Console.run
          nil
        end

        def help
          _("<p>The <b>Expert Console</b> button starts a command line interface " \
            "to the installer. It is intended for special purposes, wrong usage " \
            "might result in crash or unexpected behavior.</p>")
        end
      end

      # define the plugin
      class ConsoleButtonPlugin < MenuPlugin
        def widget
          ConsoleButton.new
        end

        # this should be the very last button
        def order
          1000
        end
      end
    end
  end
end

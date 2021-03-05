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
require "shellwords"

Yast.import "UI"

module Installation
  module Console
    # the installer console implementation for the text mode (ncurses) UI
    class Tui
      # run the passed block in a console
      def run(&block)
        start
        block.call if block_given?
      ensure
        stop
      end

      # helper method for running an interactive YaST module
      def run_yast_module(*args)
        # restore the UI back
        Yast::UI.OpenUI
        # run the YaST module
        Yast::WFM.call(*args)
        # display back the console prompt
        Yast::UI.CloseUI
      end

    private

      def start
        # dump the terminal setting at the start so we can restore them
        # back when finishing the console
        @stty = `stty --save`.chomp
        # close the UI, now the terminal can be used by other application/code
        Yast::UI.CloseUI
        # for some reason not all flags are fully restored...
        system("stty onlcr echo")
      end

      def stop
        # restore the saved terminal settings back
        system("stty #{Shellwords.escape(@stty)}")
        # reopen the UI back
        Yast::UI.OpenUI

        # in installed system the console is for some reason not fully restored
        # to the original state, ensure that some terminal flags are set at the exit
        at_exit { system("stty onlcr echo") }
      end
    end
  end
end

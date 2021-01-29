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
  class ConsoleTui
    def run(&block)
      start
      block.call if block_given?
    ensure
      stop
    end

  private

    def start
      @stty = `stty --save`.chomp
      Yast::UI.CloseUI
    end

    def stop
      system("stty #{Shellwords.escape(@stty)}")
      Yast::UI.OpenUI

      at_exit { system("stty onlcr echo") }
    end
  end
end

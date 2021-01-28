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
      Yast::UI.CloseUI
    end

    def stop
      Yast::UI.OpenUI
    end
  end
end

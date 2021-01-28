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
require "installation/console_commands"
require "installation/console_gui"
require "installation/console_tui"

Yast.import "UI"

module Installation
  class Console
    def run
      console = Yast::UI.TextMode ? ConsoleTui.new : ConsoleGui.new
      console.run do
        commands = ConsoleCommands.new
        # print the basic help text
        commands.commands(:welcome)

        # start an IRB session in the context of the "commands" object
        irb(commands)
      end
    end

  private

    def irb(context)
      # lazy loading
      require "irb"
      # enable TAB completion
      require "irb/completion"

      # see the Binding::irb method in irb.rb in the Ruby stdlib
      IRB.setup(eval("__FILE__"), argv: [])
      # use simple prompt (without current code position and no return value)
      IRB.conf[:PROMPT][:YAST] = IRB.conf[:PROMPT][:SIMPLE].dup
      IRB.conf[:PROMPT][:YAST][:RETURN] = ""
      IRB.conf[:PROMPT_MODE] = :YAST
      workspace = IRB::WorkSpace.new(context)
      IRB::Irb.new(workspace).run(IRB.conf)
    end
  end
end

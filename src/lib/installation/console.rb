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
require "installation/console/commands"
require "installation/console/gui"
require "installation/console/tui"

Yast.import "UI"

# Override the IRB to log all executed commands into the y2log so we know
# what exactly happened there (in case user did something wrong or strange...)
module IrbLogger
  # wrap the original "evaluate" method, do some logging around
  def evaluate(*args)
    statements = args[1]
    # do not log the internal IRB command for setting the last value variable
    if statements.is_a?(::String) && statements.start_with?("_ = ")
      super
    else
      Yast::Y2Logger.instance.info "Executing console command: #{statements.inspect}"
      ret = super
      Yast::Y2Logger.instance.info "Console command result: #{ret.inspect}"
      ret
    end
  end
end

# inject the code
require "irb/workspace"
module IRB # :nodoc:
  class WorkSpace
    prepend IrbLogger
  end
end

module Installation
  module Console
    class << self
      # open a console and run an interactive IRB session in it
      # testing in installed system:
      # Y2DIR=./src ruby -I src/lib -r installation/console.rb -e ::Installation::Console.run
      def run
        console = Yast::UI.TextMode ? Console::Tui.new : Console::Gui.new
        console.run do
          commands = Console::Commands.new(console)
          # print the basic help text
          commands.welcome

          # start an IRB session in the context of the "commands" object
          irb(commands)
        end
      end

    private

      # configure IRB and start an interactive session
      # @param context [Object] context in which the IRB session runs
      def irb(context)
        # lazy loading
        require "irb"
        # enable TAB completion
        require "irb/completion"

        # see the Binding::irb method in irb.rb in the Ruby stdlib
        IRB.setup(eval("__FILE__"), argv: [])
        # use a simple prompt with some customizations
        IRB.conf[:PROMPT][:YAST] = IRB.conf[:PROMPT][:SIMPLE].dup
        IRB.conf[:PROMPT][:YAST][:RETURN] = ""
        IRB.conf[:PROMPT][:YAST][:PROMPT_I] = "YaST >> "
        IRB.conf[:PROMPT_MODE] = :YAST
        workspace = IRB::WorkSpace.new(context)
        IRB::Irb.new(workspace).run(IRB.conf)
      end
    end
  end
end

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

require "pp"
require "shellwords"

require "yast"
require "installation/console/plugins"

module Installation
  module Console
    class Commands
      include Yast::I18n

      # This class implements the commands in the installer console,
      # the actual commands are implemented as plugins loaded from
      # lib/installation/console/plugins/*.rb files
      #
      # All public methods in this class are the commands available in the console,
      # that means we cannot include Yast::Logger here because it would define
      # "log" command. For logging we have to use the full form here, e.g.
      # Yast::Y2Logger.instance.info
      def initialize(console)
        textdomain "installation"

        @console = console
        Plugins.load_plugins
      end

      # print the "welcome" message with a basic help text
      def welcome
        puts "---- This is the YaST Installation Console ----"
        puts
        # this is the most important message so make it translatable,
        # the console is for experts so it is OK have the rest untranslated
        # TRANSLATORS: help text displayed in the installer command line console,
        # do not change these texts they are replaced:
        # %{cmd} is replaced by a command name
        # %{keys} is replaced by a keyboard shortcut
        puts _("Type '%{cmd}' or press %{keys} to close the console and go back " \
          "to the installer") % {cmd: "quit", keys: "Ctrl+D"}
        puts
        puts "Type 'commands' to see the available special commands"
        puts
        puts "This is a Ruby shell, you can also type any Ruby command here"
        puts "and inspect or change the YaST installer"
        puts
        puts "Hints: <Tab> completion is enabled, the command history is kept,"
        puts "you can use the usual \"readline\" features..."
        puts
      end

      # print the available commands
      def commands
        puts "Available commands:"
        puts
        print_command("quit", "Close the console and return back to the installer")

        private_methods.grep(/_description$/).sort.each do |method|
          print_command(method.to_s.sub(/_description$/, ""), send(method))
        end

        puts
      end

      # all unknown commands are handled via this "method_missing" callback
      def method_missing(method_name, *_args)
        Yast::Y2Logger.instance.info "Entered unknown command: #{method_name.inspect}"
        puts "Error: Unknown command \"#{method_name}\""
        puts
        commands
      end

      # helper for running an YaST module
      def run_yast_module(*args)
        @console.run_yast_module(*args)
      end

    private

      # print help text for a command
      def print_command(cmd, descr)
        # indent multiline descriptions
        description = descr.gsub("\n", "\n    ")
        puts "  #{cmd} - #{description}"
        puts
      end
    end
  end
end

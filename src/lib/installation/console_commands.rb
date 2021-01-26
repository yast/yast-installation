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
require "yast"

module Installation
  class ConsoleCommands
    def commands(command = nil)
      case command
      when :welcome
        puts "---- This is the YaST installation console ----"
        puts
        puts "Type 'commands' to see the available special commands"
        puts "Type 'quit' or press Ctrl+D to close the console and go back to the installer"
        puts
        puts "This is a Ruby shell, you can also type any Ruby command here"
        puts "and inspect or change the YaST installer"
      when nil
        puts "Available commands:"
        puts
        puts "  quit - close the console and return back to the installer"
        puts
        puts "  configure <module> - start a specific YaST configuration module,"
        puts "     the module can be one of the these options: network"
        puts
        puts "  repositories - display the currently configured software repositories"
      end

      puts
    end

    def configure(what = nil)
      case what
      when nil
        commands
      when :network
        Yast::WFM.call("inst_lan", [{ "skip_detection" => true }])
      else
        puts "Error: Unknown option #{what}"
      end
    end

    def network
      :network
    end

    def repositories
      Yast.import "Pkg"

      repos = Yast::Pkg.SourceGetCurrent(false).map do |repo|
        Yast::Pkg.SourceGeneralData(repo)
      end

      pp repos
    end

    def method_missing(_method_name, *_args)
      puts "Error: Unknown command"
      puts
      commands
    end
  end
end

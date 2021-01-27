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
    def initialize
      Yast.import "Pkg"
      Yast.import "Wizard"
    end

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
        puts
        puts "Hints: <Tab> completion is enabled, the command history is kept,"
        puts "you can use the usual \"readline\" features..."
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
        # we cannot run the module if there is a popup displayed, the module
        # would be displayed *below* the popup making it inaccessible :-(
        return unless wizard_dialog?

        puts "Starting the network configuration module..."
        puts
        puts "After it is finished (by pressing [Next]/[Back]/[Abort])"
        puts "press Alt+Tab to get back to this console."

        # wait a bit so the user can read the message above
        sleep(5)

        Yast::WFM.call("inst_lan", [{ "skip_detection" => true }])
      else
        puts "Error: Unknown option #{what}"
      end
    end

    def network
      :network
    end

    def repositories
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

  private

    def wizard_dialog?
      return true if Yast::Wizard.IsWizardDialog

      puts "Error: An YaST module cannot be started if there is a popup dialog"
      puts "displayed. First close this console then close the popup in the installer"
      puts "and then start the console again."

      false
    end
  end
end

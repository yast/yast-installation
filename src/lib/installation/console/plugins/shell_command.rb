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

module Installation
  module Console
    # define the "shell" command in the expert console
    class Commands
      def shell
        if Yast::UI.TextMode
          tui_shell
        else
          gui_shell
        end
      end

    private

      def tui_shell
        puts quit_hint

        # some interactive tools like "vim" get stuck when running in "fbiterm"
        # "fbiterm" sets TERM to "iterm", the workaround is to override it
        # to "vt100" (bsc#1183652)
        term = ENV["TERM"] == "iterm" ? "TERM=vt100" : ""

        system("#{term} /bin/bash")
      end

      def gui_shell
        terms = ["/usr/bin/xterm", "/usr/bin/konsole", "/usr/bin/gnome-terminal"]
        cmd = terms.find { |s| File.exist?(s) }

        if cmd
          puts "Starting a terminal application (#{cmd})..."
          puts quit_hint
          puts
          # hide possible errors, xterm complains about some missing fonts
          # in the inst-sys
          system("#{cmd} 2> /dev/null")
        else
          puts "ERROR: Cannot find any X terminal application"
        end
      end

      def quit_hint
        "Use the \"exit\" command or press Ctrl+D to return back to the YaST console."
      end

      def shell_description
        "Starts a shell session.\n#{quit_hint}"
      end
    end
  end
end

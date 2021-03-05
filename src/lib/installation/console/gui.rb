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

module Installation
  module Console
    # the installer console implementation for the graphical (Qt) UI
    class Gui
      Yast.import "Wizard"

      # open a console and run a block in it
      def run(&block)
        start
        redirect(&block)
      ensure
        stop
      end

      # helper for running an YaST module in console
      def run_yast_module(*args)
        # we cannot run any YaST module if there is a popup displayed, the module
        # would be displayed *below* the popup making it inaccessible :-(
        # make sure a wizard dialog is at the top
        return unless wizard_dialog?

        begin
          # get the window ID of the currently active window (the xterm window)
          window = `#{SWITCHER}`.chomp
        rescue Errno::ENOENT
          # if the switcher is missing display a short help
          puts "Starting an YaST configuration module..."
          puts
          puts "After it is finished (by pressing [Next]/[Back]/[Abort])"
          puts "press Alt+Tab to get back to this console."

          # wait a bit so the user can read the message above
          sleep(5)
        end

        Yast::WFM.call(*args)

        # automatically switch the window focus from YaST back to the xterm window
        system("#{SWITCHER} #{Shellwords.escape(window)}") if window
      end

    private

      # path to the window switching helper tool (from yast2-x11)
      SWITCHER = "/usr/lib/YaST2/bin/active_window".freeze

      # is the toplevel dialog a wizard dialog? We cannot run an YaST module
      # if a popup is currently displayed...
      def wizard_dialog?
        return true if Yast::Wizard.IsWizardDialog

        puts "Error: YaST modules cannot be started if there is a popup dialog"
        puts "displayed. First close this console then close the popup in the installer"
        puts "and then start the console again."

        false
      end

      # start the console, open a new xterm window
      def start
        # create a pipe for communication with the shell running in the xterm
        @read, @write = IO.pipe
        # get the /proc path for the reading end of the pipe
        read_path = fd_path(Process.pid, @read.fileno)

        # start a new xterm window, run a shell command which:
        # 1. opens a watching FD for signaling exit
        # 2. "echo" command prints the PID, the watching FD and the terminal
        #    device to the Ruby pipe above
        # 3. "read" command keeps the xterm window open until any input is sent
        #    to the watching FD
        command = "xterm -title \"YaST Installation Console\" -e bash -c \"exec {CLOSEFD}<> <(:);
                    echo \\$\\$ \\$CLOSEFD \\$(tty) > #{read_path};
                    read -u \\$CLOSEFD\" &"

        system(command)

        # read the values printed by the "echo" command above
        @pid, @close_fd, @tty = @read.readline.split
      end

      # stop the console, close the xterm window
      def stop
        # send an empty string to the waiting "read" process
        File.write(fd_path(@pid, @close_fd), "\n") if @pid && @close_fd
        # close the pipes
        @read.close if @read
        @write.close if @write
      end

      # run a block with redirected IO (redirect to the started xterm console)
      def redirect(&block)
        # remember the initial IO channels
        stdout_orig = $stdout.dup
        stderr_orig = $stderr.dup
        stdin_orig = $stdin.dup

        # redirect all IO to the xterm window (its tty device)
        $stdout.reopen(@tty)
        $stderr.reopen(@tty)
        $stdin.reopen(@tty)

        begin
          block.call
        ensure
          # restore the original IO channels
          $stdout.reopen(stdout_orig)
          $stderr.reopen(stderr_orig)
          $stdin.reopen(stdin_orig)
        end
      end

      # get /proc path for a file descriptor
      # @param pid [String, Integer] PID of the process
      # @param fd [String, Integer] file descriptor number
      def fd_path(pid, fd)
        "/proc/#{pid}/fd/#{fd}"
      end
    end
  end
end

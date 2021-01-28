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
  class ConsoleGui
    def run(&block)
      start
      redirect(&block)
    ensure
      stop
    end

  private

    def start
      @read, @write = IO.pipe
      read_path = fd_path(Process.pid, @read.fileno)

      command = "xterm -e bash -c \"exec {CLOSEFD}<> <(:);
                  echo \\$\\$ \\$CLOSEFD \\$(tty) > #{read_path};
                  read -u \\$CLOSEFD\" &"

      system(command)

      @pid, @close_fd, @tty = @read.readline.split
    end

    def stop
      File.write(fd_path(@pid, @close_fd), "\n") if @pid && @close_fd
      @read.close if @read
      @write.close if @write
    end

    def redirect(&block)
      # remember the initial IO channels
      stdout_orig = $stdout.dup
      stderr_orig = $stderr.dup
      stdin_orig = $stdin.dup

      # redirect all IO to the X terminal
      $stdout.reopen(@tty)
      $stderr.reopen(@tty)
      $stdin.reopen(@tty)

      begin
        block.call if block_given?
      ensure
        # restore the original IO channels
        $stdout.reopen(stdout_orig)
        $stderr.reopen(stderr_orig)
        $stdin.reopen(stdin_orig)
      end
    end

    def fd_path(pid, fd)
      "/proc/#{pid}/fd/#{fd}"
    end
  end
end

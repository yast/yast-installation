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

require "installation/console_commands"

module Installation
  class Console
    def run
      start
      redirect do
        commands = ConsoleCommands.new
        # print the basic help text
        commands.commands(:welcome)

        # start an IRB session in the context of the "commands" object
        irb(commands)
      end
    ensure
      stop
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
        if block_given?
          block.call
        else
          require "irb"
          binding.irb
        end
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

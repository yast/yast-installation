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
        system("/bin/bash")
      end

    private

      def shell_description
        "Starts a shell session (/bin/bash), use the \"exit\" command\n" \
        "or press Ctrl+D to return back to the YaST console"
      end
    end
  end
end

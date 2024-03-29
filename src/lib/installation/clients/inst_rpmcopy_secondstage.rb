# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# This client just calls inst_rpmcopy and returns the result.
#
# If automatic configuration is used, inst_rpmcopy is disabled,
# which not only diables it in second stage (wanted) but also
# disables it in first stage.
#
# This client is used in second stage.
module Yast
  class InstRpmcopySecondstageClient < Client
    def main
      Builtins.y2milestone("inst_rpmcopy_secondstage calling inst_rpmcopy")
      WFM.CallFunction("inst_rpmcopy", WFM.Args)
    end
  end
end

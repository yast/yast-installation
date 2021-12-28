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

# File:  test_proposal.ycp
# Summary:  For testing the network and hardware proposals.
# Author:  Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class TestProposalClient < Client
    def main
      Yast.import "UI"

      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Wizard"

      Stage.Set("continue")
      Mode.SetMode("installation")
      # Linuxrc::manual () = true;

      Wizard.CreateDialog

      @args = {}
      Ops.set(@args, "enable_back", true)
      Ops.set(@args, "enable_next", nil)
      Ops.set(@args, "proposal", WFM.Args(0))
      WFM.call("inst_proposal", [@args])
      UI.CloseDialog

      # EOF

      nil
    end
  end
end

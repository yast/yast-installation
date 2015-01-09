# encoding: utf-8

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

# File:	test_proposal.ycp
# Summary:	For testing the network and hardware proposals.
# Author:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class TestInstClientClient < Client
    def main
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Wizard"

      # map args = $[];
      # args["enable_back"] = true;
      # args["enable_next"] = true;

      @aclient = WFM.Args(0)
      return false if !Ops.is_string?(@aclient)
      @client = Convert.to_string(@aclient)

      # Client name does not start with "inst_"
      if !Builtins.regexpmatch(@client, "^inst_")
        @client = Ops.add("inst_", @client)
      end

      Stage.Set("continue")
      Mode.SetMode("installation")

      Wizard.CreateDialog
      WFM.call(@client, [])
      Wizard.CloseDialog

      true 
      # EOF
    end
  end
end

Yast::TestInstClientClient.new.main

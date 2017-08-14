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

# File:	clients/inst_check_autoinst_mode.ycp
# Package:	Installation
# Summary:	Installation mode selection, checking for autoinst.xml on floppy
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class InstCheckAutoinstModeClient < Client
    def main
      textdomain "installation"

# storage-ng
# rubocop:disable Style/BlockComments
=begin
      Yast.import "StorageDevices"
=end
      Yast.import "Mode"

      Builtins.y2milestone("Checking for autoinst.xml on floppy...")

# storage-ng
=begin
      # do we have a floppy drive attached ?
      if StorageDevices.FloppyReady
        # Try to load settings from disk, if a floppy is present
        SCR.Execute(
          path(".target.mount"),
          [StorageDevices.FloppyDevice, "/media/floppy"],
          "-t auto"
        )

        # Check for autoinst.xml. if available
        # set mode to autoinst. Later, the file is parsed and installation
        # is performed automatically.

        if Ops.greater_than(
          SCR.Read(path(".target.size"), "/media/floppy/autoinst.xml"),
          0
        )
          Builtins.y2milestone("Found control file, switching to autoinst mode")
          Mode.SetMode("autoinstallation")
          # initialize Report behavior
          # Default in autoinst mode is showing messages and warnings with timeout of 10 sec.
          # Errors are shown without timeout.
        end
        SCR.Execute(path(".target.umount"), "/media/floppy")
      end
=end

      true

      # EOF
    end
  end
end

# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC, All Rights Reserved.
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
require "installation/instsys_cleaner"

# This is a client wrapper around the InstsysCleaner class.
# It tries to free memory by removing some files from inst-sys.
# This step should be called after the target system is partitioned
# because the cleanup might remove the kernel modules which are loaded
# during disk partitioning (e.g. the filesystem modules).
module Yast
  class InstInstsysCleanupClient < Client
    Yast.import "GetInstArgs"

    def main
      return :back if GetInstArgs.going_back

      ::Installation::InstsysCleaner.make_clean

      :next
    end
  end
end

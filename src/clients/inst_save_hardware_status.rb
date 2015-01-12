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

# File:	installation/general/inst_save_hardware_status.ycp
# Module:	Installation
# Summary:	Save status of configured hardware
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  class InstSaveHardwareStatusClient < Client
    def main
      textdomain "installation"

      Yast.import "GetInstArgs"

      return :auto if GetInstArgs.going_back # going backwards? # don't execute this once more

      Builtins.y2milestone("Saving configured devices...")

      @out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "\n" \
            "hwinfo --pci --block --mouse --keyboard --isdn --save-config=all\n" \
            "\n" \
            "[ -d /var/lib/hardware/udi/org/freedesktop/Hal/devices ] && perl -pi -e \"s/hwinfo.configured = 'new'/hwinfo.configured = 'no'/\" /var/lib/hardware/udi/org/freedesktop/Hal/devices/*"
        )
      )

      Builtins.y2milestone("Result: %1", @out)

      :auto
    end
  end
end

Yast::InstSaveHardwareStatusClient.new.main

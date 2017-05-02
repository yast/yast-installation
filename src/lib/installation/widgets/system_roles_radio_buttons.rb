# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "cwm/widget"
require "installation/services"
require "installation/custom_patterns"
require "installation/system_role"
require "installation/widgets/system_role_reader"

Yast.import "DefaultDesktop"
Yast.import "ProductControl"
Yast.import "IP"
Yast.import "Hostname"

module Installation
  module Widgets
    class SystemRolesRadioButtons < CWM::RadioButtons
      include SystemRoleReader

      alias_method :store_orig, :store
      def store
        # set flag to show custom patterns only if custom role selected
        CustomPatterns.show = value == "custom"
        store_orig

        if value == "custom"
          # for custom role do not use any desktop
          Yast::DefaultDesktop.SetDesktop(nil)
        else
          # force reset of Default Desktop, because it is cached and when going
          # forward and backward, it can be changed
          Yast::DefaultDesktop.ForceReinit
        end
      end

      def vspacing
        1
      end
    end
  end
end

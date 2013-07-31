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

# *************
# FILE          : inst_x11.ycp
# ***************
# PROJECT       : YaST2
#               :
# AUTHOR        : Marcus Schäfer <ms@suse.de>
#               :
# BELONGS TO    : YaST2
#               : (X11 integration part using SaX2/ISaX)
#               :
# DESCRIPTION   : The installation workflow will call inst_x11
#               : This module will check if we have X11 installed
#               : and import the main X11 module (x11.ycp)
#               :
# STATUS        : Development
#  *
#  * $Id$
module Yast
  class InstX11Client < Client
    def main
      Yast.import "X11Version"
      Yast.import "Mode"
      Yast.import "Installation"
      Yast.import "Arch"
      Yast.import "GetInstArgs"

      @next = GetInstArgs.enable_next
      @back = GetInstArgs.enable_back

      #==========================================
      # Check if X11 is installed
      #------------------------------------------
      if X11Version.have_x11 && Installation.x11_setup_needed &&
          Arch.x11_setup_needed
        @ret = WFM.CallFunction("x11", [@back, @next])
        return deep_copy(@ret)
      else
        return :next
      end
    end
  end
end

Yast::InstX11Client.new.main

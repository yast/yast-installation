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

# File:	clients/inst_prepare_images.ycp
# Package:	Installation
# Summary:	Installation done (also) from image
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
#
# $Id$

require "y2packager/resolvable"

module Yast
  class InstPrepareImageClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "Packages"
      Yast.import "ImageInstallation"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"
      Yast.import "Installation"

      textdomain "installation"

      return :back if GetInstArgs.going_back

      WFM.call("clone_system", [{"target_path" => "/root/autoinst.xml"}])

      # TODO: restart yast + modify install.inf to start autoyast

      :abort
    end
  end
end

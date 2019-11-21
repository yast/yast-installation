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

      Builtins.y2milestone("Preparing image for package selector")

      # set repo to get images from
      ImageInstallation.SetRepo(Ops.get(Packages.theSources, 0, 0))

      @all_patterns = Y2Packager::Resolvable.find(kind: :pattern)

      @patterns_to_install = Builtins.maplist(@all_patterns) do |one_patern|
        if one_patern.status == :selected ||
           one_patern.status == :installed
          next one_patern.name
        else
          next ""
        end
      end

      @patterns_to_install = Builtins.filter(@patterns_to_install) do |one_pattern|
        one_pattern != "" && !one_pattern.nil?
      end

      if @patterns_to_install == ImageInstallation.last_patterns_selected
        Builtins.y2milestone("List of selected patterns hasn't changed...")
        return :auto
      end
      ImageInstallation.last_patterns_selected = deep_copy(@patterns_to_install)

      # list images for currently selected patterns
      Builtins.y2milestone(
        "Currently selected patterns: %1",
        @patterns_to_install
      )

      # avoid useles calls
      if Ops.greater_than(Builtins.size(@patterns_to_install), 0)
        ImageInstallation.FindImageSet(@patterns_to_install)
      end

      Builtins.y2milestone("Images for installation ready")

      :auto
    end
  end
end

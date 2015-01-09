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

#  * Module:	inst_features.ycp
#  *
#  * Authors:	Anas Nashif <nashif@suse.de>
#  *
#  * Purpose:     Enable all the set features in the control file
#                 before going into proposal
#  * $Id$
module Yast
  class InstFeaturesClient < Client
    def main
      textdomain "installation"

      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Timezone"
      Yast.import "Keyboard"
      Yast.import "Language"
      Yast.import "Installation"
      Yast.import "Console"

      # Timezone
      if ProductFeatures.GetStringFeature("globals", "timezone") != ""
        Timezone.Set(
          ProductFeatures.GetStringFeature("globals", "timezone"),
          true
        )
      end

      # Keyboard
      if ProductFeatures.GetStringFeature("globals", "keyboard") != ""
        Keyboard.default_kbd = ProductFeatures.GetStringFeature(
          "globals",
          "keyboard"
        )
        Keyboard.SetConsole(
          ProductFeatures.GetStringFeature("globals", "keyboard")
        )
        Keyboard.SetX11(ProductFeatures.GetStringFeature("globals", "keyboard"))
      end

      if ProductFeatures.GetStringFeature("globals", "language") != ""
        @language = ProductFeatures.GetStringFeature("globals", "language")
        # Set it in the Language module.
        Language.Set(@language)

        # Set Console font
        Console.SelectFont(@language)

        # Set it in YaST2
        Language.WfmSetLanguage
      end

      # Bugzilla #327791
      # Online Repositories - default status

      # Feature is not defined
      if ProductFeatures.GetFeature("software", "online_repos_preselected") == ""
        # Default is true - selected
        Installation.productsources_selected = true
        # Defined
      else
        @default_status_or = ProductFeatures.GetBooleanFeature(
          "software",
          "online_repos_preselected"
        )

        # if not set, default is "true"
        @default_status_or = true if @default_status_or.nil?
        Installation.productsources_selected = @default_status_or
      end

      Builtins.y2milestone(
        "Use Online Repositories (default): %1",
        Installation.productsources_selected
      )

      :auto
    end
  end
end

Yast::InstFeaturesClient.new.main

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

# File:	clients/inst_initialize.ycp
# Package:	Installation (Second Stage)
# Summary:	Installation mode selection, initialize installation system
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class InstInitializationClient < Client
    def main
      # This client should be called in the secong stage installation
      # before netprobe, netsetup ...
      # At least to create UI

      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Stage"

      # TRANSLATORS: dialog help
      @helptext = _("Installation is being initialized.")
      # TRANSLATORS: dialog progress message
      @label = _("Initializing the installation...")

      if Stage.cont
        # TRANSLATORS: dialog help
        @helptext = _("<p>Please wait...</p>")
        # TRANSLATORS: dialog progress message
        @label = _("Preparing the initial system configuration...")
      end

      @content = VBox(Label(@label))

      # TRANSLATORS: dialog caption
      @caption = _("Initializing")

      Wizard.SetContents(@caption, @content, @helptext, false, false)
      Wizard.SetTitleIcon("yast-software")

      :auto

      # EOF
    end
  end
end

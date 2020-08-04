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

require "installation/old_package_checker"

module Yast
  # Asks user to really do the installation/update.
  class InstDoitClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "PackagesUI"

      Yast.import "Label"

      Yast.include self, "installation/misc.rb"

      return :next if Mode.autoinst && !AutoinstConfig.Confirm

      # old functionality replaced with this function-call
      # bugzilla #256627
      PackagesUI.ConfirmLicenses

      # warn about installing old packages
      ::Installation::OldPackageChecker.run

      # function in installation/misc.ycp
      # bugzilla #219097
      @confirmed = confirmInstallation

      if @confirmed
        Builtins.y2milestone(
          "User confirmed %1",
          Mode.update ? "update" : "installation"
        )

        Wizard.SetContents(
          # TRANSLATORS: dialog caption
          _("Installation - Warming Up"),
          VBox(
            # TRANSLATORS: starting the installation process
            # dialog cotent (progress information)
            Label(_("Starting Installation..."))
          ),
          # TRANSLATORS: dialog help
          _("<p>Installation is just about to start!</p>"),
          false,
          false
        )
      end

      @confirmed ? :next : :back
    end
  end
end

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

# File:
#	inst_fallback_controlfile.ycp
#
# Module:
#	Installation
#
# Authors:
#	Lukas Ocilka <locilka@suse.cz>
#
# Summary:
#	This client is used as the very first dialog when the fallback
#	control file is used. See BNC #440982
#
# $Id$
#
module Yast
  class InstFallbackControlfileClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "GetInstArgs"
      Yast.import "Popup"

      Builtins.y2error("-------------------------------------")
      Builtins.y2error("--- USING A FALLBACK CONTROL FILE ---")
      Builtins.y2error("-------------------------------------")

      # heading text
      @heading_text = Label.WarningMsg

      @contents = Frame(
        Label.WarningMsg,
        MarginBox(
          2,
          1,
          # error description
          Label(
            _(
              "YaST was unable to find the correct control file.\n" +
                "We are using a fall-back one. This should not happen\n" +
                "and it is worth reporting a bug."
            )
          )
        )
      )

      # help text
      @help_text = _(
        "<p>A fallback control file contains installation and update\nworkflows unified for all products.</p>"
      )

      Wizard.SetContents(
        @heading_text,
        @contents,
        @help_text,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      Wizard.EnableAbortButton

      Wizard.SetTitleIcon("yast-misc")

      @ret = nil

      while true
        @ret = UI.UserInput
        Builtins.y2milestone("UserInput() returned %1", @ret)

        if @ret == :back
          break
        elsif (@ret == :abort || @ret == :cancel) &&
            Popup.ConfirmAbort(:painless)
          Wizard.RestoreNextButton
          @ret = :abort
          break
        elsif @ret == :next
          break
        else
          Builtins.y2error("Uknown ret: %1", @ret)
        end
      end

      Convert.to_symbol(@ret)
    end
  end
end

Yast::InstFallbackControlfileClient.new.main

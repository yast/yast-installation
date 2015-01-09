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

# File:	clients/inst_welcome.ycp
# Package:	Installation
# Summary:	Generic Welcome File
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
module Yast
  class InstWelcomeClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"
      Yast.import "Wizard"
      Yast.import "Directory"
      Yast.import "GetInstArgs"
      Yast.import "RichText"
      Yast.import "CustomDialogs"
      Yast.import "Language"

      @argmap = GetInstArgs.argmap

      @default_patterns = ["welcome.%1.txt", "welcome.txt"]

      @directory = Ops.get_string(@argmap, "directory", Directory.datadir)

      if Ops.get_string(@argmap, "directory", "") != ""
        @directory = Ops.add(Directory.custom_workflow_dir, @directory)
      end

      @patterns = Convert.convert(
        Ops.get(@argmap, "patterns", @default_patterns),
        from: "any",
        to:   "list <string>"
      )

      @welcome = CustomDialogs.load_file_locale(
        @patterns,
        @directory,
        Language.language
      )
      Builtins.y2debug("welcome map: %1", @welcome)

      @display = UI.GetDisplayInfo
      @space = Ops.get_boolean(@display, "TextMode", true) ? 1 : 3

      # dialog caption
      @caption = _("Welcome")

      # welcome text 1/4
      @text = _("<p><b>Welcome!</b></p>") +
        # welcome text 2/4
        _(
          "<p>There are a few more steps to take before your system is ready to\n" +
            "use. YaST will now guide you through some basic configuration.  Click\n" +
            "<b>Next</b> to continue. </p>\n" +
            "            \n"
        )

      # welcome text
      @welcome_text = Ops.get_string(@welcome, "text", "") != "" ?
        Ops.get_string(@welcome, "text", "") :
        @text

      # help ttext
      @help = _(
        "<p>Click <b>Next</b> to perform the\nbasic configuration of the system.</p>\n"
      )

      @rt = Empty()

      if Builtins.regexpmatch(@welcome_text, "</.*>")
        @rt = RichText(Id(:welcome_text), @welcome_text)
      else
        Builtins.y2debug("plain text")
        @rt = RichText(Id(:welcome_text), Opt(:plainText), @welcome_text)
      end

      @contents = VBox(
        VSpacing(@space),
        HBox(
          HSpacing(Ops.multiply(2, @space)),
          @rt,
          HSpacing(Ops.multiply(2, @space))
        ),
        VSpacing(2)
      )

      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        GetInstArgs.enable_back,
        GetInstArgs.enable_next
      )
      Wizard.SetFocusToNextButton

      @ret = UI.UserInput

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::InstWelcomeClient.new.main

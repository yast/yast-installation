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

# File:	installation/general/inst_relase_notes.ycp
# Module:	Installation
# Summary:	Display release notes
# Authors:	Arvin Schnell <arvin@suse.de>
#
# Display release notes.
#
# $Id$
module Yast
  class ReleaseNotesPopupClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"
      textdomain "installation"

      Yast.import "Language"
      Yast.import "Report"
      Yast.import "Label"
      Yast.import "Stage"
      Yast.import "Packages"
      Yast.import "Mode"

      # filename of release notes
      @file = ""

      # release notes
      @text = ""

      Builtins.y2milestone("Calling: Release Notes Popup")

      if !(Mode.live_installation ? find_release_notes : load_release_notes)
        # error report
        Report.Error(_("Cannot load release notes."))
        return nil
      end

      @text = Ops.add(
        # beginning of the rich text with the release notes
        _(
          "<p><b>These are the release notes for the initial release. They are\n" +
            "part of the installation media. During installation, if a connection\n" +
            "to the Internet is available, you can download updated release notes\n" +
            "from the SUSE Linux Web server.</b></p>\n"
        ),
        @text
      )

      # bugzilla #221222, #213239
      @display_info = UI.GetDisplayInfo
      @min_size_x = 76
      @min_size_y = 22

      # textmode
      if Ops.get_boolean(@display_info, "TextMode", true)
        @min_size_x = Ops.divide(
          Ops.multiply(
            Builtins.tointeger(Ops.get_integer(@display_info, "Width", 80)),
            3
          ),
          4
        )
        @min_size_y = Ops.divide(
          Ops.multiply(
            Builtins.tointeger(Ops.get_integer(@display_info, "Height", 25)),
            2
          ),
          3
        )
        @min_size_x = 76 if Ops.less_than(@min_size_x, 76)
        @min_size_y = 22 if Ops.less_than(@min_size_y, 22)
        Builtins.y2milestone(
          "X/x Y/y %1/%2 %3/%4",
          Ops.get_integer(@display_info, "Width", 80),
          @min_size_x,
          Ops.get_integer(@display_info, "Height", 25),
          @min_size_y
        ) 
        # GUI
      else
        @min_size_x = 100
        @min_size_y = 30
      end

      @contents = MinSize(
        @min_size_x,
        @min_size_y,
        VBox(
          VSpacing(0.5),
          Left(Heading(_("Release Notes"))),
          RichText(Id(:text), @text),
          VSpacing(0.5),
          ButtonBox(
            PushButton(Id(:close), Opt(:okButton, :key_F9), Label.CloseButton)
          ),
          VSpacing(0.5)
        )
      )

      UI.OpenDialog(@contents)
      @contents = nil
      UI.SetFocus(:close)

      # FIXME: richtext eats return key, but only in NCurses and we want to
      # make users read release notes (and make PgDn work). For Next, F10 is
      # availbale
      UI.SetFocus(Id(:text))

      @ret = nil
      begin
        @ret = UI.UserInput
      end until @ret == :close || @ret == :back
      UI.CloseDialog

      Builtins.y2milestone("Finishing: Release Notes Popup")

      deep_copy(@ret)
    end

    # FIXME similar function in packager/include/load_release_notes.ycp

    # function to load release notes
    def load_release_notes
      path_to_relnotes = "/docu"
      source_id = 0
      if Stage.initial
        source_id = Ops.get(Packages.theSources, 0, 0)
      else
        sources = Pkg.SourceStartCache(true)
        source_id = Ops.get(sources, 0, 0)
      end
      path_templ = Ops.add(path_to_relnotes, "/RELEASE-NOTES.%1.rtf")
      Builtins.y2debug("Path template: %1", path_templ)
      tmp = Builtins.sformat(path_templ, Language.language)
      Builtins.y2debug("Trying to get %1", tmp)
      tmp = Pkg.SourceProvideDigestedFile(source_id, 1, tmp, false)
      if tmp == nil
        tmp = Builtins.sformat(
          path_templ,
          Ops.get(Builtins.splitstring(Language.language, "_"), 0, "")
        )
        Builtins.y2debug("Trying to get %1", tmp)
        tmp = Pkg.SourceProvideDigestedFile(source_id, 1, tmp, false)
      end
      if tmp == nil
        tmp = Builtins.sformat(path_templ, "en")
        Builtins.y2debug("Trying to get %1", tmp)
        tmp = Pkg.SourceProvideDigestedFile(source_id, 1, tmp, false)
      end
      return false if tmp == nil

      @text = Convert.to_string(SCR.Read(path(".target.string"), [tmp, ""]))
      return true if @text != "" && @text != nil
      false
    end

    # in live installation, the release notes are in the /usr/doc directory, find right file there (bug 332862)
    def find_release_notes
      Builtins.y2milestone("Finding release notes in local filesystem")
      # FIXME hardcoded product name
      path_to_relnotes = "/usr/share/doc/release-notes/openSUSE/"
      path_templ = Ops.add(path_to_relnotes, "/RELEASE-NOTES.%1.rtf")
      Builtins.y2debug("Path template: %1", path_templ)
      tmp = Builtins.sformat(path_templ, Language.language)
      Builtins.y2debug("Trying to get %1", tmp)
      if Ops.greater_or_equal(
          0,
          Convert.to_integer(SCR.Read(path(".target.size"), tmp))
        )
        tmp = Builtins.sformat(
          path_templ,
          Ops.get(Builtins.splitstring(Language.language, "_"), 0, "")
        )
        Builtins.y2debug("Trying to get %1", tmp)
      end
      if Ops.greater_or_equal(
          0,
          Convert.to_integer(SCR.Read(path(".target.size"), tmp))
        )
        tmp = Builtins.sformat(path_templ, "en")
        Builtins.y2debug("Trying to get %1", tmp)
      end
      if Ops.greater_or_equal(
          0,
          Convert.to_integer(SCR.Read(path(".target.size"), tmp))
        )
        return false
      end

      Builtins.y2milestone("Reading file %1", tmp)
      @text = Convert.to_string(SCR.Read(path(".target.string"), [tmp, ""]))
      return true if @text != "" && @text != nil
      false
    end
  end
end

Yast::ReleaseNotesPopupClient.new.main

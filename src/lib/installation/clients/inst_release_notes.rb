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
#		Lukas Ocilka <locilka@suse.de>
#		Jens Daniel Schmidt <jdsn@suse.de>
#
# Display release notes.
#
# $Id$
module Yast
  class InstReleaseNotesClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "GetInstArgs"
      Yast.import "CustomDialogs"
      Yast.import "Directory"
      Yast.import "Language"
      Yast.import "Mode"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "CommandLine"

      @argmap = GetInstArgs.argmap

      # Bugzilla #269914, CommanLine "support"
      # argmap is only a map, CommandLine uses string parameters
      if Builtins.size(@argmap) == 0 &&
          Ops.greater_than(Builtins.size(WFM.Args), 0)
        Mode.SetUI("commandline")
        Builtins.y2milestone("Mode CommandLine not supported, exiting...")
        # TRANSLATORS: error message - the module does not provide command line interface
        CommandLine.Print(
          _("There is no user interface available for this module.")
        )
        return :auto
      end

      @minwidtprodsel = 0
      @relnotesproducts = []

      @basedirectory = "/usr/share/doc/release-notes"
      @directory = ""
      @prodnamelen = 0

      # --- //

      if Ops.get_string(@argmap, "directory", "") != ""
        @basedirectory = Ops.add(Directory.custom_workflow_dir, @basedirectory)
      end

      @readproducts = []
      # Release notes might be missing
      if FileUtils.Exists(@basedirectory) &&
          FileUtils.IsDirectory(@basedirectory)
        # sort release notes according to time (newest first),
        # so the latest product is selected in the default tab (bnc#827590)
        @out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("ls -t1 '%1'", @basedirectory)
          )
        )
        @readproducts = Builtins.splitstring(
          Ops.get_string(@out, "stdout", ""),
          "\n"
        )
        # bnc #407922
        # not all objects need to be directories
        @is_directory = nil
        @readproducts = Builtins.filter(@readproducts) do |one_prod|
          next false if one_prod == "" # there's empty line at the end of ls output
          @is_directory = FileUtils.IsDirectory(
            Builtins.sformat("%1/%2", @basedirectory, one_prod)
          )
          if @is_directory != true
            Builtins.y2warning(
              "'%1' in '%2' is not a directory",
              one_prod,
              @basedirectory
            )
          end
          @is_directory
        end
      end

      @languages_translations = CreateLanguagesTranslations()
      @languages_of_relnotes = {}

      @preferred_langs = [
        Language.language,
        Ops.get(Builtins.splitstring(Language.language, "_"), 0, ""),
        "en_US",
        "en_GB",
        "en"
      ]

      @minwidthlang = {}

      @cleanproduct_product = {}
      # Creating term `ComboBox with languages for every single product
      Builtins.foreach(@readproducts) do |product|
        # beautify product string
        cleanproduct = Builtins.mergestring(
          Builtins.splitstring(product, "_"),
          " "
        )
        @relnotesproducts = Builtins.add(@relnotesproducts, cleanproduct)
        if Ops.less_than(@minwidtprodsel, Builtins.size(cleanproduct))
          @minwidtprodsel = Builtins.size(cleanproduct)
        end
        Ops.set(@cleanproduct_product, cleanproduct, product)
        @prodnamelen = Ops.add(@prodnamelen, Builtins.size(cleanproduct))
        # read release notes
        directory = Ops.add(Ops.add(Ops.add(@basedirectory, "/"), product), "/")
        relnotest_list = Convert.convert(
          SCR.Read(path(".target.dir"), directory),
          from: "any",
          to:   "list <string>"
        )
        relnotest_list = Builtins.filter(relnotest_list) do |one_relnotes|
          Builtins.regexpmatch(one_relnotes, "^RELEASE-NOTES..*.rtf$")
        end
        combobox_items = []
        Builtins.foreach(relnotest_list) do |one_relnotes|
          relnotes_lang = Builtins.regexpsub(
            one_relnotes,
            "^RELEASE-NOTES.(.*).rtf$",
            "\\1"
          )
          lang_name = Ops.get(@languages_translations, relnotes_lang, "")
          # combobox item
          if lang_name.nil? || lang_name == ""
            lang_name = Builtins.sformat(_("Language: %1"), relnotes_lang)
          end
          # set minimal width (maximal length of language name)
          if Ops.less_than(
            Ops.get(@minwidthlang, product, 0),
            Builtins.size(lang_name)
          )
            Ops.set(@minwidthlang, product, Builtins.size(lang_name))
          end
          combobox_items = Builtins.add(
            combobox_items,
            Item(
              Id(Builtins.sformat("%1%2", directory, one_relnotes)),
              lang_name
            )
          )
        end
        # Selecting default language
        preferred_found = false
        Builtins.foreach(@preferred_langs) do |preffered_lang|
          conter = -1
          Builtins.foreach(combobox_items) do |one_item|
            conter = Ops.add(conter, 1)
            item_id2 = Ops.get_string(one_item, [0, 0], "")
            if Builtins.regexpmatch(
              item_id2,
              Builtins.sformat("RELEASE-NOTES.%1.rtf$", preffered_lang)
            )
              preferred_found = true
              raise Break
            end
          end
          if preferred_found
            Ops.set(
              combobox_items,
              conter,
              Builtins.add(Ops.get(combobox_items, conter) { Item(Id(nil), nil) }, true)
            )
            raise Break
          end
        end
        Ops.set(@languages_of_relnotes, product, Builtins.sort(combobox_items) do |a, b|
          Ops.less_than(Ops.get_string(a, 1, ""), Ops.get_string(b, 1, ""))
        end)
      end

      # caption for dialog "Release Notes"
      @caption = _("Release Notes")

      @relnoteslayout = nil
      @relnotesscreen = MarginBox(
        2.0,
        0.2,
        # combobox
        VBox(
          Left(
            ReplacePoint(
              Id(:lang_rp),
              ComboBox(Id(:lang), Opt(:notify), _("&Language"), [])
            )
          ),
          ReplacePoint(Id(:content_rp), RichText(Id(:relnotescontent), ""))
        )
      )

      # if there are more products installed, show them in tabs or with
      # combo box, bnc #359137 (do not show tab for one product)
      if Ops.less_or_equal(Builtins.size(@relnotesproducts), 1)
        @relnoteslayout = deep_copy(@relnotesscreen)
        # use DumpTab or ComboBox layout
      elsif UI.HasSpecialWidget(:DumbTab) &&
          (Ops.less_than(Builtins.size(@relnotesproducts), 4) &&
            Ops.less_than(@prodnamelen, 90) ||
            Ops.greater_than(Builtins.size(@relnotesproducts), 3) &&
              Ops.less_than(@prodnamelen, 70))
        @relnoteslayout = DumbTab(@relnotesproducts, @relnotesscreen)
        # doesn't have DumpTab or too many products
      else
        @relnoteslayout = VBox(
          Left(
            MinWidth(
              Ops.add(
                # +2 thingies on the right
                @minwidtprodsel,
                2
              ),
              ComboBox(
                Id(:productsel),
                Opt(:notify),
                _("&Product"),
                @relnotesproducts
              )
            )
          ),
          @relnotesscreen
        )
      end

      @contents = VBox(VSpacing(0.5), @relnoteslayout, VSpacing(0.5))

      # help text for dialog "Release Notes"
      @help = _(
        "<p>The <b>release notes</b> for the installed Linux system provide a brief\nsummary of new features and changes.</p>\n"
      )

      # in normal mode no BackAbortNext-button layout
      # bugzilla #262440
      if Mode.normal
        Wizard.OpenNextBackDialog
        Wizard.DisableBackButton
        Wizard.DisableAbortButton
        Wizard.SetNextButton(:next, Label.CloseButton)
        Wizard.EnableNextButton

        Wizard.SetContents(@caption, @contents, @help, false, true)

        # installation
      else
        Wizard.SetContents(
          @caption,
          @contents,
          @help,
          GetInstArgs.enable_back,
          GetInstArgs.enable_next
        )
      end

      Wizard.SetDesktopTitleAndIcon("release_notes")
      Wizard.SetFocusToNextButton

      # Default settings
      UI.ChangeWidget(Id(:lang), :Enabled, false)
      if UI.WidgetExists(:productsel) &&
          Ops.less_than(Builtins.size(@relnotesproducts), 2)
        UI.ChangeWidget(Id(:productsel), :Enabled, false)
      end

      # for debugging
      # UI::DumpWidgetTree();

      # Init the first product
      if Ops.greater_than(Builtins.size(@relnotesproducts), 0)
        RedrawRelnotesProduct(:tab, Ops.get(@relnotesproducts, 0, ""))
      else
        SetNoReleaseNotesInfo()
      end

      @ret = nil
      loop do
        @ret = Wizard.UserInput

        if @ret == :abort
          break if Mode.normal
          break if Popup.ConfirmAbort(:incomplete)
        elsif @ret == :help
          Wizard.ShowHelp(@help)
          # using combobox for products
        elsif @ret == :productsel
          RedrawRelnotesProduct(
            :tab,
            Convert.to_string(UI.QueryWidget(Id(:productsel), :Value))
          )
        elsif @ret == :lang
          RedrawRelnotesLang(
            Convert.to_string(UI.QueryWidget(Id(:lang), :Value))
          )
          # using tabs for products
        elsif Ops.is_string?(@ret)
          RedrawRelnotesProduct(:tab, @ret)
        end
        break if [:next, :back].include?(@ret)
      end
      Wizard.CloseDialog if Mode.normal

      Convert.to_symbol(@ret)
    end

    def CreateLanguagesTranslations
      ret = {}
      all_languages = Language.GetLanguagesMap(false)
      Builtins.foreach(all_languages) do |short, translations|
        translation = nil
        if Ops.get_string(translations, 4, "") != ""
          translation = Ops.get_string(translations, 4, "")
        elsif Ops.get_string(translations, 1, "") != ""
          translation = Ops.get_string(translations, 1, "")
        elsif Ops.get_string(translations, 0, "") != ""
          translation = Ops.get_string(translations, 0, "")
        end
        Ops.set(ret, short, translation)
        # fallback for short names without xx_YY
        if Builtins.regexpmatch(short, "_")
          short = Builtins.regexpsub(short, "^(.*)_.*$", "\\1")
          Ops.set(ret, short, translation) if Ops.get(ret, short).nil?
        end
      end

      # exceptions
      ret["en"] = ret["en_US"] if ret["en"] && ret["en_US"]
      ret["zh"] = ret["zh_CN"] if ret["zh"] && ret["zh_CN"]
      ret["pt"] = ret["pt_PT"] if ret["pt"] && ret["pt_PT"]

      deep_copy(ret)
    end

    def UsePlainText(file)
      ret = UI.TextMode && FileUtils.Exists(file)
      if ret
        Builtins.y2milestone(
          "Found .txt file \"%1\" with release notes, will use it for TUI.",
          file
        )
      end
      ret
    end

    def RedrawRelnotesLang(use_file)
      text_file = Ops.add(
        Builtins.regexpsub(use_file, "^(.*).rtf$", "\\1"),
        ".txt"
      )
      plain_text = UsePlainText(text_file)

      contents = Convert.to_string(
        SCR.Read(path(".target.string"), plain_text ? text_file : use_file)
      )

      if contents.nil? || contents == ""
        Builtins.y2error("Wrong relnotesfile: %1", use_file)
      elsif plain_text
        UI.ReplaceWidget(
          Id(:content_rp),
          RichText(Id(:relnotescontent), Opt(:plainText), contents)
        )
      else
        UI.ReplaceWidget(
          Id(:content_rp),
          RichText(Id(:relnotescontent), contents)
        )
      end

      nil
    end

    def RedrawRelnotesProduct(redraw_type, current_ret)
      current_ret = deep_copy(current_ret)
      if redraw_type == :tab
        product = Ops.get(
          @cleanproduct_product,
          Builtins.tostring(current_ret),
          ""
        )

        UI.ReplaceWidget(
          Id(:lang_rp),
          MinWidth(
            Ops.add(
              Ops.get(
                # +2 for thingies on the right
                @minwidthlang,
                product,
                16
              ),
              2
            ),
            HSquash(
              # TRANSLATORS: Combo box
              ComboBox(
                Id(:lang),
                Opt(:notify),
                _("&Language"),
                Ops.get(@languages_of_relnotes, product, [])
              )
            )
          )
        )
        if Ops.greater_than(
          Builtins.size(Ops.get(@languages_of_relnotes, product, [])),
          1
        )
          UI.ChangeWidget(Id(:lang), :Enabled, true)
        else
          UI.ChangeWidget(Id(:lang), :Enabled, false)
        end
      end

      RedrawRelnotesLang(Convert.to_string(UI.QueryWidget(Id(:lang), :Value)))

      nil
    end

    def SetNoReleaseNotesInfo
      # informative message in RichText widget
      UI.ChangeWidget(
        Id(:relnotescontent),
        :Value,
        _("<p>No release notes have been installed.</p>")
      )

      nil
    end
  end
end

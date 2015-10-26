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

require "yaml"
require "fileutils"

module Yast
  # This client shows main dialog for choosing the language,
  # keyboard and accepting the license.
  class InstComplexWelcomeClient < Client
    import "Console"
    import "GetInstArgs"
    import "InstData"
    import "Keyboard"
    import "Label"
    import "Language"
    import "Mode"
    import "Pkg"
    import "Popup"
    import "ProductLicense"
    import "Report"
    import "Stage"
    import "Timezone"
    import "UI"
    import "Wizard"

    def main
      textdomain "installation"

      # ------------------------------------- main part of the client -----------

      if data_stored? && !GetInstArgs.going_back
        apply_data
        return :next
      end

      @argmap = GetInstArgs.argmap

      @language = Language.language

      @text_mode = Language.GetTextMode

      @license_id = Ops.get(Pkg.SourceGetCurrent(true), 0, 0)
      @license_ui_id = Builtins.tostring(@license_id)

      # ----------------------------------------------------------------------
      # Build dialog
      # ----------------------------------------------------------------------
      # heading text
      heading_text = _("Language, Keyboard and License Agreement")

      # this type of contents will be shown only for initial installation dialog
      @contents = VBox(
        VWeight(1, VStretch()),
        Left(
          HBox(
            HWeight(1, Left(language_selection)),
            HSpacing(3),
            HWeight(1, Left(keyboard_selection))
          )
        ),
        Left(
          HBox(
            HWeight(1, HStretch()),
            HSpacing(3),
            HWeight(1, Left(TextEntry(Id(:keyboard_test), _("K&eyboard Test"))))
          )
        ),
        VWeight(
          30,
          Left(
            HSquash(
              VBox(
                HBox(
                  Left(Label(Opt(:boldFont), _("License Agreement"))),
                  HStretch()
                ),
                # bnc #438100
                HSquash(
                  MinWidth(
                    # BNC #607135
                    @text_mode ? 85 : 106,
                    Left(ReplacePoint(Id(:base_license_rp), Empty()))
                  )
                ),
                VSpacing(@text_mode ? 0.1 : 0.5),
                MinHeight(
                  1,
                  HBox(
                    # Will be replaced with license checkbox if required
                    ReplacePoint(Id(:license_checkbox_rp), Empty()),
                    HStretch(),
                    # ID: #ICW_B1 button
                    PushButton(
                      Id(:show_fulscreen_license),
                      # TRANSLATORS: button label
                      _("License &Translations...")
                    )
                  )
                )
              )
            )
          )
        ),
        VWeight(1, VStretch())
      )


      # Screen title for the first interactive dialog

      Wizard.SetContents(
        heading_text,
        @contents,
        help_text,
        Ops.get_boolean(@argmap, "enable_back", true),
        Ops.get_boolean(@argmap, "enable_next", true)
      )

      initialize_widgets

      @keyboard = ""

      ProductLicense.ShowLicenseInInstallation(:base_license_rp, @license_id)

      # bugzilla #206706
      return :auto if Mode.autoinst

      # If accepting the license is required, show the check-box
      Builtins.y2milestone(
        "Acceptance needed: %1 => %2",
        @license_ui_id,
        ProductLicense.AcceptanceNeeded(@license_ui_id)
      )
      if ProductLicense.AcceptanceNeeded(@license_ui_id)
        UI.ReplaceWidget(:license_checkbox_rp, license_agreement_checkbox)
      end

      loop do
        @ret = UI.UserInput
        Builtins.y2milestone("UserInput() returned %1", @ret)

        if @ret == :back
          break
        elsif @ret == :abort && Popup.ConfirmAbort(:painless)
          Wizard.RestoreNextButton
          @ret = :abort
          break
        elsif @ret == :keyboard
          ReadCurrentUIState()
          Keyboard.Set(@keyboard)
          Keyboard.user_decision = true
        elsif @ret == :license_agreement
          InstData.product_license_accepted = Convert.to_boolean(
            UI.QueryWidget(Id(:license_agreement), :Value)
          )
        elsif @ret == :next || @ret == :language && !Mode.config
          ReadCurrentUIState()

          if @ret == :next
            # BNC #448598
            # Check whether the license has been accepted only if required
            if ProductLicense.AcceptanceNeeded(@license_ui_id) &&
                !LicenseAccepted()
              next
            end

            next if !Language.CheckIncompleteTranslation(@language)

            Language.CheckLanguagesSupport(@language) if Stage.initial
          end

          if SetLanguageIfChanged(@ret)
            @ret = :again
            break
          end

          if @ret == :next
            store_data
            break
          end
        elsif @ret == :show_fulscreen_license
          UI.OpenDialog(AllLicensesDialog())
          ProductLicense.ShowFullScreenLicenseInInstallation(
            :full_screen_license_rp,
            @license_id
          )
          UI.CloseDialog
        end
      end

      Convert.to_symbol(@ret)
    end

  private

    def initialize_widgets
      Wizard.EnableAbortButton

      UI.ChangeWidget(Id(:language), :Value, @language)

      if Keyboard.user_decision == true
        UI.ChangeWidget(Id(:keyboard), :Value, Keyboard.current_kbd)
      else
        @kbd = Keyboard.GetKeyboardForLanguage(@language, "english-us")
        UI.ChangeWidget(Id(:keyboard), :Value, @kbd)
      end

      # In case of going back, Release Notes button may be shown, retranslate it (bnc#886660)
      # Assure that relnotes have been downloaded first
      if !InstData.release_notes.empty?
        Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
      end

      UI.SetFocus(Id(:language))
    end

    def help_text
      # help text for initial (first time) language screen
      @help_text = _(
        "<p>\n" \
          "Choose the <b>Language</b> and the <b>Keyboard layout</b> to be used during\n" \
          "installation and for the installed system.\n" \
          "</p>\n"
      ) +
        # help text, continued
        # Describes the #ICW_B1 button
        _(
          "<p>\n" \
            "The license must be accepted before the installation continues.\n" \
            "Use <b>License Translations...</b> to show the license in all available translations.\n" \
            "</p>\n"
        ) +
        # help text, continued
        _(
          "<p>\n" \
            "Click <b>Next</b> to proceed to the next dialog.\n" \
            "</p>\n"
        ) +
        # help text, continued
        _(
          "<p>\n" \
            "Nothing will happen to your computer until you confirm\n" \
            "all your settings in the last installation dialog.\n" \
            "</p>\n"
        ) +
        # help text, continued
        _(
          "<p>\n" \
            "Select <b>Abort</b> to abort the\n" \
            "installation process at any time.\n" \
            "</p>\n"
        )
    end

    def AllLicensesDialog
      # As long as possible
      # bnc #385257
      HBox(
        VSpacing(@text_mode ? 21 : 25),
        VBox(
          Left(
            # TRANSLATORS: dialog caption
            Heading(_("License Agreement"))
          ),
          VSpacing(@text_mode ? 0.1 : 0.5),
          HSpacing(82),
          HBox(
            VStretch(),
            ReplacePoint(Id(:full_screen_license_rp), Opt(:vstretch), Empty())
          ),
          ButtonBox(
            PushButton(
              Id(:close),
              Opt(:okButton, :default, :key_F10),
              Label.OKButton
            )
          )
        )
      )
    end

    def language_selection
      ComboBox(
        Id(:language),
        Opt(:notify, :hstretch),
        # combo box label
        _("&Language"),
        Language.GetLanguageItems(:first_screen)
      )
    end

    def keyboard_selection
      ComboBox(
        Id(:keyboard),
        Opt(:notify, :hstretch),
        # combo box label
        _("&Keyboard Layout"),
        Keyboard.GetKeyboardItems
      )
    end

    # BNC #448598
    # License sometimes doesn't need to be manually accepted
    def license_agreement_checkbox
      Left(
        CheckBox(
          # bnc #359456
          Id(:license_agreement),
          Opt(:notify),
          # TRANSLATORS: check-box
          _("I &Agree to the License Terms."),
          InstData.product_license_accepted
        )
      )
    end

    def LicenseAccepted
      if @license_acc == true
        return true
      else
        UI.SetFocus(Id(:license_agreement))
        Report.Message(_("You must accept the license to install this product"))
        return false
      end
    end

    def ReadCurrentUIState
      @language = Convert.to_string(UI.QueryWidget(Id(:language), :Value))
      @keyboard = Convert.to_string(UI.QueryWidget(Id(:keyboard), :Value))

      if ProductLicense.AcceptanceNeeded(@license_ui_id)
        @license_acc = Convert.to_boolean(
          UI.QueryWidget(Id(:license_agreement), :Value)
        )
      else
        @license_acc = true
      end

      nil
    end

    def retranslate_yast
      Console.SelectFont(@language)
      # no yast translation for nn_NO, use nb_NO as a backup
      if @language == "nn_NO"
        Builtins.y2milestone("Nynorsk not translated, using Bokm\u00E5l")
        Language.WfmSetGivenLanguage("nb_NO")
      else
        Language.WfmSetLanguage
      end
    end

    # Returns true if the dialog needs redrawing
    def SetLanguageIfChanged(ret)
      ret = deep_copy(ret)
      if @language != Language.language
        Builtins.y2milestone(
          "Language changed from %1 to %2",
          Language.language,
          @language
        )
        Timezone.ResetZonemap

        # Set it in the Language module.
        Language.Set(@language)
        Language.languages = [Language.RemoveSuffix(@language)]
      end
      # Check and set CJK languages
      if Stage.initial || Stage.firstboot
        if ret == :language && Language.SwitchToEnglishIfNeeded(true)
          Builtins.y2debug("UI switched to en_US")
        elsif ret == :language
          retranslate_yast
        end
      end

      if ret == :language
        # Display newly translated dialog.
        Wizard.SetFocusToNextButton
        return true
      end

      if ret == :next
        Keyboard.Set(@keyboard)

        # Language has been set already.
        # On first run store users decision as default.
        Builtins.y2milestone("Resetting to default language")
        Language.SetDefault

        Timezone.SetTimezoneForLanguage(@language)

        if !Stage.initial && !Mode.update
          # save settings (rest is saved in LanguageWrite)
          Keyboard.Save
          Timezone.Save
        end

        # Bugzilla #354133
        Builtins.y2milestone(
          "Adjusting package and text locale to %1",
          @language
        )
        Pkg.SetPackageLocale(@language)
        Pkg.SetTextLocale(@language)

        # In case of normal installation, solver run will follow without this explicit call
        if Mode.live_installation && Language.PackagesModified
          Language.PackagesInit(Language.languages)
        end

        Builtins.y2milestone(
          "Language: '%1', system encoding '%2'",
          @language,
          WFM.GetEncoding
        )
      end

      false
    end

    DATA_PATH = "/var/lib/YaST2/complex_welcome_store.yaml"
    def data_stored?
      ::File.exists?(DATA_PATH)
    end

    def store_data
      data = {
        "language" => @language,
        "keyboard" => @keyboard
      }

      File.write(DATA_PATH, data.to_yaml)
    end

    def apply_data
      data = YAML.load(File.read(DATA_PATH))
      @language = data["language"]
      @keyboard = data["keyboard"]

      SetLanguageIfChanged(:next)
      retranslate_yast

      ::FileUtils.rm_rf(DATA_PATH)
    end
  end unless defined? Yast::InstComplexWelcomeClient
end

Yast::InstComplexWelcomeClient.new.main

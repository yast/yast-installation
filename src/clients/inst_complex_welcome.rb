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
require "yast"

module Yast
  # This client shows main dialog for choosing the language,
  # keyboard and accepting the license.
  class InstComplexWelcomeClient < Client
    include Yast::Logger

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

    HEADING_TEXT = N_("Language, Keyboard and License Agreement")

    def main
      # bnc#206706
      return :auto if Mode.autoinst

      textdomain "installation"

      # ------------------------------------- main part of the client -----------
      if data_stored? && !GetInstArgs.going_back
        apply_data
        return :next
      end

      @argmap = GetInstArgs.argmap

      @language = Language.language
      @keyboard = ""

      @license_id = Ops.get(Pkg.SourceGetCurrent(true), 0, 0)

      # ----------------------------------------------------------------------
      # Build dialog
      # ----------------------------------------------------------------------
      # Screen title for the first interactive dialog
      initialize_dialog

      return event_loop
    end

  private
    def event_loop
      loop do
        ret = UI.UserInput
        log.info "UserInput() returned #{ret}"

        case ret
        when :back
          return ret
        when :abort
          next unless Popup.ConfirmAbort(:painless)
          Wizard.RestoreNextButton
          return ret
        when :keyboard
          read_ui_state
          Keyboard.Set(@keyboard)
          Keyboard.user_decision = true
        when :license_agreement
          InstData.product_license_accepted = UI.QueryWidget(Id(:license_agreement), :Value)
        when :language
          next if Mode.config
          read_ui_state
          change_language
          Wizard.SetFocusToNextButton
          return :again
        when :next
          next if Mode.config
          read_ui_state

          # BNC #448598
          # Check whether the license has been accepted only if required
          if @licence_required && !LicenseAccepted()
            next
          end

          next if !Language.CheckIncompleteTranslation(@language)

          Language.CheckLanguagesSupport(@language) if Stage.initial

          setup_final_choice

          store_data
          return :next
        when :show_fulscreen_license
          UI.OpenDialog(all_licenses_dialog)
          ProductLicense.ShowFullScreenLicenseInInstallation(
            :full_screen_license_rp,
            @license_id
          )
          UI.CloseDialog
        else
          raise "unknown input '#{ret}'"
        end
      end
    end

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

    def all_licenses_dialog
      # As long as possible
      # bnc #385257
      HBox(
        VSpacing(text_mode? ? 21 : 25),
        VBox(
          Left(
            # TRANSLATORS: dialog caption
            Heading(_("License Agreement"))
          ),
          VSpacing(text_mode? ? 0.1 : 0.5),
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
      return true if @license_acc

      UI.SetFocus(Id(:license_agreement))
      Report.Message(_("You must accept the license to install this product"))
    end

    def read_ui_state
      @language = UI.QueryWidget(Id(:language), :Value)
      @keyboard = UI.QueryWidget(Id(:keyboard), :Value)

      @license_acc = @licence_required ? UI.QueryWidget(Id(:license_agreement), :Value) : true
    end

    def retranslate_yast
      Console.SelectFont(@language)
      # no yast translation for nn_NO, use nb_NO as a backup
      if @language == "nn_NO"
        log.info "Nynorsk not translated, using Bokm\u00E5l"
        Language.WfmSetGivenLanguage("nb_NO")
      else
        Language.WfmSetLanguage
      end
    end

    def change_language
      return if @language == Language.language

      log.info "Language changed from #{Language.language} to #{@language}"
      Timezone.ResetZonemap

      # Set it in the Language module.
      Language.Set(@language)
      Language.languages = [Language.RemoveSuffix(@language)]

      if Language.SwitchToEnglishIfNeeded(true)
        log.debug "UI switched to en_US"
      else
        # Display newly translated dialog.
        retranslate_yast
      end
    end

    def setup_final_choice
      Keyboard.Set(@keyboard)

      # Language has been set already.
      # On first run store users decision as default.
      log.info "Resetting to default language"
      Language.SetDefault

      Timezone.SetTimezoneForLanguage(@language)

      if !Stage.initial && !Mode.update
        # save settings (rest is saved in LanguageWrite)
        Keyboard.Save
        Timezone.Save
      end

      # Bugzilla #354133
      log.info "Adjusting package and text locale to #{@language}"
      Pkg.SetPackageLocale(@language)
      Pkg.SetTextLocale(@language)

      # In case of normal installation, solver run will follow without this explicit call
      if Mode.live_installation && Language.PackagesModified
        Language.PackagesInit(Language.languages)
      end

      log.info "Language: '#{@language}', system encoding '#{WFM.GetEncoding}'"
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

    def text_mode?
      return @text_mode unless @text_mode.nil?

      @text_mode = Language.GetTextMode
    end

    def dialog_content
      # this type of contents will be shown only for initial installation dialog
      VBox(
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
                    text_mode? ? 85 : 106,
                    Left(ReplacePoint(Id(:base_license_rp), Empty()))
                  )
                ),
                VSpacing(text_mode? ? 0.1 : 0.5),
                MinHeight(
                  1,
                  HBox(
                    # Will be replaced with license checkbox if required
                    ReplacePoint(Id(:license_checkbox_rp), Empty()),
                    HStretch(),
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
    end

    def initialize_dialog
      Wizard.SetContents(
        _(HEADING_TEXT),
        dialog_content,
        help_text,
        GetInstArgs.argmap.fetch("enable_back", true),
        GetInstArgs.argmap.fetch("enable_next", true)
      )

      initialize_widgets

      ProductLicense.ShowLicenseInInstallation(:base_license_rp, @license_id)

      # If accepting the license is required, show the check-box
      @licence_required = ProductLicense.AcceptanceNeeded(@license_id.to_s)

      log.info "Acceptance needed: #{@id} => #{@licence_required}"
      if @licence_required
        UI.ReplaceWidget(:license_checkbox_rp, license_agreement_checkbox)
      end
    end
  end unless defined? Yast::InstComplexWelcomeClient
end

Yast::InstComplexWelcomeClient.new.main

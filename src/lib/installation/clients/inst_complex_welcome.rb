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
require "installation/dialogs/complex_welcome"
require "y2packager/product"

Yast.import "Console"
Yast.import "FileUtils"
Yast.import "GetInstArgs"
Yast.import "InstData"
Yast.import "InstShowInfo"
Yast.import "Keyboard"
Yast.import "Language"
Yast.import "Mode"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "Stage"
Yast.import "Timezone"
Yast.import "Wizard"
Yast.import "WorkflowManager"

module Yast
  # This client shows main dialog for choosing the language, keyboard,
  # selecting the product/accepting the license.
  class InstComplexWelcomeClient < Client
    include Yast::Logger
    extend Yast::I18n

    BETA_FILE = "/README.BETA".freeze

    # Main client method
    def main
      if FileUtils.Exists(BETA_FILE) && !GetInstArgs.going_back
        InstShowInfo.show_info_txt(BETA_FILE)
      end

      # bnc#206706
      return :auto if Mode.autoinst

      textdomain "installation"

      Yast::Wizard.EnableAbortButton
      show_release_notes

      loop do
        dialog_result = ::Installation::Dialogs::ComplexWelcome.run(
          products, disable_buttons: disable_buttons
        )
        result = handle_dialog_result(dialog_result)
        next unless result
        return result == :next ? merge_and_run_workflow : result
      end
    end

    # Handle dialog's result
    #
    # @param value [Symbol] Dialog's return value (:next, :language_changed, etc.)
    # @return [Symbol,nil] Client's return value. Nil if client should not
    #   finish yet.
    def handle_dialog_result(value)
      case value
      when :language_changed
        return if Mode.config
        change_language
        :again

      when :keyboard_changed
        Keyboard.user_decision = true
        nil

      when :abort
        return :abort if Yast::Popup.ConfirmAbort(:painless)
        nil

      when :next
        return if Mode.config
        return unless Language.CheckIncompleteTranslation(Language.language)
        if selected_product.nil?
          Yast::Popup.Error(_("Please select a product to install."))
          return nil
        end
        setup_final_choice
        :next

      else
        value
      end
    end

  private

    # Merge selected product's workflow and go to next step
    #
    # @see Yast::WorkflowManager.merge_product_workflow
    def merge_and_run_workflow
      Yast::WorkflowManager.merge_product_workflow(selected_product)
      Yast::ProductControl.RunFrom(Yast::ProductControl.CurrentStep + 1, true)
    end

    # Change YaST interface language
    #
    # Most of the work is done by #retranslate_yast. If changing to english if
    # needed, no configuration changes are performed.
    #
    # @see #retranslate_yast
    def change_language
      if Language.SwitchToEnglishIfNeeded(true)
        log.debug "UI switched to en_US"
      else
        # Display newly translated dialog.
        retranslate_yast
      end
    end

    # Set up system according to user choices
    def setup_final_choice
      # Language has been set already.
      # On first run store users decision as default.
      log.info "Resetting to default language"
      Language.SetDefault

      Timezone.SetTimezoneForLanguage(Language.language)

      if !Stage.initial && !Mode.update
        # save settings (rest is saved in LanguageWrite)
        Keyboard.Save
        Timezone.Save
      end

      # Bugzilla #354133
      log.info "Adjusting package and text locale to #{@language}"
      Pkg.SetPackageLocale(Language.language)
      Pkg.SetTextLocale(Language.language)

      # In case of normal installation, solver run will follow without this explicit call
      if Mode.live_installation && Language.PackagesModified
        selected_languages = Language.languages.split(",") << Language.language
        Language.PackagesInit(selected_languages)
      end

      log.info "Language: '#{Language.language}', system encoding '#{WFM.GetEncoding}'"
    end

    # Change YaST interface language
    def retranslate_yast
      Console.SelectFont(Language.language)
      # no yast translation for nn_NO, use nb_NO as a backup
      # FIXME: remove the hack, please
      if Language.language == "nn_NO"
        log.info "Nynorsk not translated, using Bokm\u00E5l"
        Language.WfmSetGivenLanguage("nb_NO")
      else
        Language.WfmSetLanguage
      end
    end

    # Show release notes if they have been downloaded
    def show_release_notes
      return if InstData.release_notes.empty?
      Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
    end

    # Return the list of base products
    #
    # @return [Array<Y2Packager::Product>] List of available base products
    def products
      @products ||= Y2Packager::Product.available_base_products
    end

    # Convenience method to find out the selected base product
    #
    # @return [Y2Packager::Product] Selected base product
    def selected_product
      Y2Packager::Product.selected_base
    end

    # Buttons to disable according to GetInstArgs
    #
    # @return [Array<Symbol>] Buttons to disable (:next, :back)
    def disable_buttons
      [:back, :next].reject do |button|
        GetInstArgs.argmap.fetch("enable_#{button}", true)
      end
    end
  end unless defined? Yast::InstComplexWelcomeClient
end

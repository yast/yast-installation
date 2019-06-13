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

require "fileutils"
require "pp"
require "yaml"
require "yast"

require "installation/dialogs/complex_welcome"
require "y2packager/medium_type"
require "y2packager/product"
require "y2packager/product_control_product"
require "y2packager/product_location"
require "y2packager/product_sorter"

Yast.import "Console"
Yast.import "FileUtils"
Yast.import "GetInstArgs"
Yast.import "InstShowInfo"
Yast.import "InstURL"
Yast.import "Keyboard"
Yast.import "Language"
Yast.import "Mode"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "ProductFeatures"
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

    def initialize
      textdomain "installation"
    end

    # Main client method
    def main
      if FileUtils.Exists(BETA_FILE) && !GetInstArgs.going_back
        InstShowInfo.show_info_txt(BETA_FILE)
      end

      # bnc#206706
      return :auto if Mode.auto

      Yast::Wizard.EnableAbortButton

      loop do
        dialog_result = ::Installation::Dialogs::ComplexWelcome.run(
          products, disable_buttons: disable_buttons
        )
        result = handle_dialog_result(dialog_result)
        next unless result

        return result if !available_products? || result != :next
        # in the online installation the workflow is merged after registering the system
        return result if Y2Packager::MediumType.online?
        return merge_and_run_workflow
      end
    end

  private

    # Handle dialog's result
    #
    # @param value [Symbol] Dialog's return value (:next, :language_changed, etc.)
    # @return [Symbol,nil] Client's return value. Nil if client should not
    #   finish yet.
    def handle_dialog_result(value)
      case value
      when :abort
        return :abort if Yast::Popup.ConfirmAbort(:painless)
        nil

      when :next
        return if Mode.config
        return unless Language.CheckIncompleteTranslation(Language.language)

        return if available_products? && !product_selection_finished?

        setup_final_choice
        :next

      else
        value
      end
    end

    # Merge selected product's workflow and go to next step
    #
    # @see Yast::WorkflowManager.merge_product_workflow
    def merge_and_run_workflow
      Yast::WorkflowManager.merge_product_workflow(selected_product)
      Yast::ProductControl.RunFrom(Yast::ProductControl.CurrentStep + 1, true)
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

    # Return the list of base products available
    #
    # When a base product is being forced, the list will contains only it.
    #
    # In update mode, when there are more than 1 product, this method will return an empty
    # list because the dialog will not show the license (we do not know which product we are
    # upgrading yet) nor the product selector (as you cannot change the product during upgrade).
    #
    # @return [Array<Y2Packager::Product>,Array<Y2Packager::ProductControlProduct] List of
    #    available base products; if any, a list containing only the forced base product;
    #    empty list in update mode.
    def products
      return @products if @products

      @products = Array(Y2Packager::Product.forced_base_product || available_base_products)
      @products = [] if Mode.update && @products.size > 1
      @products
    end

    # Returns all available base products
    #
    # @return [Array<Y2Packager::Product>, Array<Y2Packager::ProductControlProduct>] List of available base products
    def available_base_products
      return @available_base_products if @available_base_products

      case Y2Packager::MediumType.type
      when :online
        # read the products from the control.xml
        @available_base_products = Y2Packager::ProductControlProduct.products
        log.info "Found base products in the control.xml: #{@available_base_products.pretty_inspect}"

        # we cannot continue, the control.xml in the installer is invalid
        raise "control.xml does not define any base products!" if @available_base_products.empty?
      when :offline
        url = InstURL.installInf2Url("")
        @available_base_products = Y2Packager::ProductLocation
                                   .scan(url)
                                   .select { |p| p.details && p.details.base }
                                   .sort(&::Y2Packager::PRODUCT_SORTER)
        log.info "Found base products on the offline medium: #{@available_base_products.pretty_inspect}"
      else
        @available_base_products = Y2Packager::Product.available_base_products
      end

      @available_base_products
    end

    # Determine whether some product is available or not
    #
    # @return [Boolean] false if no product available; true otherwise
    def available_products?
      !products.empty?
    end

    # Convenience method to find out the selected base product
    #
    # @return [Y2Packager::Product] Selected base product
    def selected_product
      if Y2Packager::MediumType.online?
        Y2Packager::ProductControlProduct.selected
      else
        Y2Packager::Product.selected_base
      end
    end

    # Buttons to disable according to GetInstArgs
    #
    # @return [Array<Symbol>] Buttons to disable (:next, :back)
    def disable_buttons
      [:back, :next].reject do |button|
        GetInstArgs.argmap.fetch("enable_#{button}", true)
      end
    end

    # Determine whether selected product license should be confirmed
    #
    # If more than 1 product exists, it is supposed to be accepted later.
    #
    # @return [Boolean] true if it should be accepted; false otherwise.
    def license_confirmation_required?
      return false if products.size > 1
      selected_product.license_confirmation_required?
    end

    # Reports an error if no product is selected or if the selected product
    # requires a license agreement and it has not been confirmed.
    #
    # @return [Boolean] true if a product has been selected and license
    # agreement confirmed when required; false otherwise
    def product_selection_finished?
      if selected_product.nil?
        return true if products.size <= 1
        Yast::Popup.Error(_("Please select a product to install."))
        return false
      elsif license_confirmation_required? && !selected_product.license_confirmed?
        Yast::Popup.Error(_("You must accept the license to install this product"))
        return false
      end

      true
    end
  end unless defined? Yast::InstComplexWelcomeClient
end

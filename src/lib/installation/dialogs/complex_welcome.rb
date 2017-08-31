# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "cwm"
require "cwm/dialog"

require "installation/widgets/product_selector"
require "installation/widgets/language_keyboard_selection"
require "y2packager/widgets/product_license"

Yast.import "UI"

module Installation
  module Dialogs
    # This class implements a welcome dialog for the installer
    #
    # The dialog contains:
    #
    # * A language/keyboard selector
    # * If only 1 product is available, it shows the product's license.
    # * If more than 1 product is available, it shows the product selector.
    class ComplexWelcome < CWM::Dialog
      # @return [Array<Y2Packager::Product>] List of available products
      attr_reader :products

      # @return [Array<Symbol>] list of buttons to disable (:next, :abort, :back)
      attr_reader :disable_buttons

      # Constructor
      #
      # @param [Array<Y2Packager::Product>] List of available products
      # @param [Array<Symbol>] List of buttons to disable
      def initialize(products, disable_buttons: [])
        @products = products
        @disable_buttons = disable_buttons.map { |b| "#{b}_button" }
      end

      # Returns the dialog title
      #
      # The title can vary depending if the license agreement or the product
      # selection is shown.
      #
      # @return [String] Dialog's title
      def title
        if show_license?
          _("Language, Keyboard and License Agreement")
        else
          _("Language, Keyboard and Product Selection")
        end
      end

      # Dialog content
      #
      # @return [Yast::Term] Dialog's content
      def contents
        VBox(
          filling,
          Left(::Installation::Widgets::LanguageKeyboardSelection.new),
          show_license? ? product_license : product_selector,
          filling
        )
      end

    private

      # Product selection widget
      #
      # @return [::Installation::Widgets::ProductSelector]
      def product_selector
        ::Installation::Widgets::ProductSelector.new(products)
      end

      # Product license widget
      #
      # @return [Y2Packager::Widgets::ProductLicense]
      def product_license
        Y2Packager::Widgets::ProductLicense.new(products.first)
      end

      # Determine whether the license must be shown
      #
      # The license will be shown when only one product is available.
      #
      # @return [Boolean] true if the license must be shown; false otherwise
      def show_license?
        products.size == 1
      end

      # Fill space if needed
      def filling
        (show_license? || Yast::UI.TextMode) ? Empty() : VWeight(1, VStretch())
      end

    end
  end
end

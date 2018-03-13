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
require "y2country/widgets/language_selection"
require "y2country/widgets/keyboard_selection"
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
      # @param products        [Array<Y2Packager::Product>] List of available products
      # @param disable_buttons [Array<Symbol>] List of buttons to disable
      def initialize(products, disable_buttons: [])
        textdomain "installation"
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
        return license_or_product_title if available_products?

        _("Language and Keyboard Selection")
      end

      # Dialog content
      #
      # @return [Yast::Term] Dialog's content
      def contents
        @contents = VBox(
          filling,
          locale_settings,
          license_or_product_content,
          filling
        )
      end

      def skip_store_for
        [:redraw]
      end

      def run
        res = nil

        loop do
          res = super
          break if res != :redraw
        end

        res
      end

    private

      def locale_settings
        Left(
          VBox(
            Left(
              HBox(
                HWeight(1, Left(Y2Country::Widgets::LanguageSelection.new(emit_event: true))),
                HSpacing(3),
                HWeight(1, Left(Y2Country::Widgets::KeyboardSelectionCombo.new))
              )
            ),
            Left(
              HBox(
                HWeight(1, HStretch()),
                HSpacing(3),
                HWeight(
                  1,
                  Left(InputField(Id(:keyboard_test), Opt(:hstretch), _("K&eyboard Test")))
                )
              )
            )
          )
        )
      end

      # Product selection widget
      #
      # @return [::Installation::Widgets::ProductSelector]
      def product_selector
        ::Installation::Widgets::ProductSelector.new(products, skip_validation: true)
      end

      # Product license widget
      #
      # @return [Y2Packager::Widgets::ProductLicense]
      def product_license
        Y2Packager::Widgets::ProductLicense.new(products.first, skip_validation: true)
      end

      # Determine whether the license must be shown
      #
      # The license will be shown when only one product is available.
      #
      # @return [Boolean] true if the license must be shown; false otherwise
      def show_license?
        products.size == 1
      end

      # Determine whether some product is available or not
      #
      # @return [Boolean] false if no product available; true otherwise
      def available_products?
        !products.empty?
      end

      # License or Product content
      #
      # Shows the product selection if there is more than one product or the
      # license agreement if there is only one.
      #
      # @return [Yast::Term] Product selection content; Empty() if no products
      def license_or_product_content
        return Empty() unless available_products?

        show_license? ? product_license : product_selector
      end

      # UI to fill space if needed
      def filling
        if show_license? || Yast::UI.TextMode
          Empty()
        else
          VWeight(1, VStretch())
        end
      end

      # Title of the dialog in case there is some product available.
      #
      # The title can vary depending if the license agreement or the product
      # selection is shown.
      #
      # @return [String] Dialog's title
      def license_or_product_title
        if show_license?
          _("Language, Keyboard and License Agreement")
        else
          _("Language, Keyboard and Product Selection")
        end
      end
    end
  end
end

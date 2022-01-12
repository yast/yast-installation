# ------------------------------------------------------------------------------
# Copyright (c) 2022 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"

require "y2packager/medium_type"
require "y2packager/product_sorter"

Yast.import "Pkg"
Yast.import "Popup"
Yast.import "AddOnProduct"
Yast.import "WorkflowManager"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      include Yast::Logger

      attr_reader :items, :products
      attr_reader :product

      # @param products [Array<Y2Packager::Product>] products to display
      # @param skip_validation [Boolean] Skip value validation
      def initialize(products, skip_validation: false)
        super()
        @products = products
        @items = products.sort(&Y2Packager::PRODUCT_SORTER).map { |p| [item_id(p), p.label] }
        @skip_validation = skip_validation
        textdomain "installation"
      end

      def hspacing
        1
      end

      def label
        _("Product to Install")
      end

      def init
        selected = products.find(&:selected?)
        # disable changing the base product after registering it, in the offline
        # installation we cannot easily change the base product repository
        disable if registered? || offline_product_selected?
        return unless selected

        self.value = item_id(selected)
      end

      def store
        log.info "Selected product: #{value}"
        @product = products.find { |p| item_id(p) == value }
        log.info "Found product: #{@product}"

        return unless @product

        @product.select unless @product.selected?
      end

      def validate
        return true if value || skip_validation?

        Yast::Popup.Error(_("Please select a product to install."))
        false
      end

      # Determine whether the validation should be skipped
      #
      # @see #initialize
      def skip_validation?
        @skip_validation
      end

      # Determine whether the system is registered
      def registered?
        require "registration/registration"
        Registration::Registration.is_registered?
      rescue LoadError
        false
      end

      # has been an offline installation product selected?
      # @return [Boolean] true if an offline installation product has been selected
      def offline_product_selected?
        Y2Packager::MediumType.offline? && products.any?(&:selected?)
      end

      # unique widget ID for the product
      # @return [String] widget ID
      def item_id(prod)
        return prod.dir if prod.respond_to?(:dir)

        "#{prod.name}-#{prod.version}-#{prod.arch}"
      end
    end
  end
end

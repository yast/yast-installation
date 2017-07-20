require "yast"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      attr_reader :items, :products

      # @param products [Array<Installation::Product>] to display
      def initialize(products)
        @products = products
        @items = products.map { |p| [p.name, p.label, p.selected?] }
        textdomain "installation"
      end

      def hspacing
        1
      end

      def label
        _("Product to Install")
      end

      def store
        # TODO: deselect the previously selected product when going back
        product = products.find { |p| p.name == value }
        product.select if product
      end

      # TODO: validation, a product must be selected
    end
  end
end

require "yast"
Yast.import "Pkg"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      include Yast::Logger

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
        log.info "Selected product: #{value}"
        product = products.find { |p| p.name == value }
        log.info "Found product: #{product}"

        return unless product

        # reset both YaST and user selection (when going back or any products
        # selected by YaST in the previous steps)
        Yast::Pkg.PkgApplReset
        Yast::Pkg.PkgReset
        product.select
      end

      # TODO: validation, a product must be selected
    end
  end
end

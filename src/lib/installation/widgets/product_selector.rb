require "yast"
Yast.import "Pkg"
Yast.import "Popup"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      include Yast::Logger

      attr_reader :items, :products
      attr_reader :product

      # @param products [Array<Installation::Product>] to display
      def initialize(products)
        @products = products
        @items = products.map { |p| [p.name, p.label] }
        textdomain "installation"
      end

      def hspacing
        1
      end

      def label
        _("Product to Install")
      end

      def init
        selected = products.find { |p| p.selected? }
        return unless selected

        self.value = selected.name
      end

      def store
        log.info "Selected product: #{value}"
        @product = products.find { |p| p.name == value }
        log.info "Found product: #{@product}"

        return unless @product

        # reset both YaST and user selection (when going back or any products
        # selected by YaST in the previous steps)
        Yast::Pkg.PkgApplReset
        Yast::Pkg.PkgReset
        @product.select
      end

      def validation
        return true if value

        Yast::Popup.Error(_("Please select product to install."))
        false
      end
    end
  end
end

require "yast"

require "y2packager/product_control_product"

Yast.import "Pkg"
Yast.import "Popup"
Yast.import "AddOnProduct"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      include Yast::Logger

      attr_reader :items, :products
      attr_reader :product

      # @param products [Array<Installation::Product>] to display
      # @param skip_validation [Boolean] Skip value validation
      def initialize(products, skip_validation: false)
        @products = products
        @items = products.map { |p| [product_id(p), p.label] }
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
        disable if registered?
        return unless selected

        self.value = product_id(selected)
      end

      def store
        log.info "Selected product: #{value}"
        @product = products.find { |p| product_id(p) == value }
        log.info "Found product: #{@product}"

        return unless @product

        if @product.is_a?(Y2Packager::ProductControlProduct)
          Y2Packager::ProductControlProduct.selected = @product
        else
          # reset both YaST and user selection (when going back or any products
          # selected by YaST in the previous steps)
          Yast::Pkg.PkgApplReset
          Yast::Pkg.PkgReset
          @product.select

          # Reselecting existing add-on-products for installation again
          Yast::AddOnProduct.selected_installation_products.each do |product|
            log.info "Reselecting add-on product #{product} for installation"
            Yast::Pkg.ResolvableInstall(product, :product, "")
          end
        end
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

      def product_id(prod)
        "#{prod.name}-#{prod.version}-#{prod.arch}"
      end
    end
  end
end

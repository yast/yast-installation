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
      # @param skip_validation [Boolean] Skip value validation
      def initialize(products, skip_validation: false)
        @products = products
        @items = products.map { |p| [p.name, p.label] }
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
    end
  end
end

require "yast"

require "y2packager/medium_type"
require "y2packager/product_control_product"

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

      # @param products [Array<Installation::Product>] to display
      # @param skip_validation [Boolean] Skip value validation
      def initialize(products, skip_validation: false)
        @products = products
        @items = products.map { |p| [item_id(p), p.label] }
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

        # online product from control.xml
        if @product.is_a?(Y2Packager::ProductControlProduct)
          Y2Packager::ProductControlProduct.selected = @product
        # offline product from the medium repository
        elsif @product.is_a?(Y2Packager::ProductLocation)
          # in offline installation add the repository with the selected base product
          show_popup = true
          base_url = Yast::InstURL.installInf2Url("")
          log_url = Yast::URL.HidePassword(base_url)
          Yast::Packages.Initialize_StageInitial(show_popup, base_url, log_url, @product.dir)
          # select the product to install
          Yast::Pkg.ResolvableInstall(@product.details && @product.details.product, :product, "")
          # initialize addons and the workflow manager
          Yast::AddOnProduct.SetBaseProductURL(base_url)
          Yast::WorkflowManager.SetBaseWorkflow(false)
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

      # has been an offline installation product selected?
      # @return [Boolean] true if an offline installation product has been selected
      def offline_product_selected?
        Y2Packager::MediumType.offline? && products.any?(&:selected?)
      end

      # unique widget ID for the product
      # @return [String] widget ID
      def item_id(prod)
        return prod.dir if prod.is_a?(Y2Packager::ProductLocation)
        "#{prod.name}-#{prod.version}-#{prod.arch}"
      end
    end
  end
end

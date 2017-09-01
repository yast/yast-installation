require "yast"

require "cwm/dialog"
require "installation/widgets/product_selector"
require "y2packager/product"

Yast.import "ProductControl"
Yast.import "WorkflowManager"

module Installation
  module Dialogs
    # The dialog is used to select from available product that can do system installation.
    # Currently it is mainly used for LeanOS that have on one media more products.
    class ProductSelection < CWM::Dialog
      class << self
        attr_accessor :selected_package
      end

      def initialize
        textdomain "installation"
      end

      def title
        _("Product Selection")
      end

      def products
        Y2Packager::Product.available_base_products
      end

      def selector
        @selector ||= Widgets::ProductSelector.new(products)
      end

      def contents
        VBox(selector)
      end

      # enhances default run by additional action if next is pressed
      def run
        res = super
        return res if res != :next

        Yast::WorkflowManager.merge_product_workflow(product)
        # run new steps for product
        Yast::ProductControl.RunFrom(Yast::ProductControl.CurrentStep + 1, true)
      end
    end
  end
end

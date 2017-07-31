require "yast"

require "cwm/dialog"
require "installation/widgets/product_selector"
require "installation/product_reader"

Yast.import "ProductControl"
Yast.import "WorkflowManager"

module Installation
  module Dialogs
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
        ProductReader.available_base_products
      end

      def selector
        @selector ||= Widgets::ProductSelector.new(products)
      end

      def contents
        VBox(selector)
      end

      def run
        res = super

        if res == :next
          # remove already selected if it is not first run of dialog
          if self.class.selected_package
            Yast::WorkflowManager.RemoveWorkflow(:package, 0, self.class.selected_package)
          end
          product = selector.product
          Yast::WorkflowManager.AddWorkflow(:package, 0, product.installation_package)
          Yast::WorkflowManager.MergeWorkflows
          Yast::WorkflowManager.RedrawWizardSteps
          self.class.selected_package = product.installation_package
          # run new steps for product
          res = Yast::ProductControl.RunFrom(Yast::ProductControl.CurrentStep + 1, true)
        end

        res
      end
    end
  end
end

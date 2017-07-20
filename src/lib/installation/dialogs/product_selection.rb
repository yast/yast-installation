require "yast"

require "cwm/dialog"
require "installation/widgets/product_selector"
require "installation/product_reader"

Yast.import "ProductControl"
Yast.import "WorkflowManager"

module Installation
  module Dialogs
    class ProductSelection < CWM::Dialog
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
          # TODO: real mapping to selected product
          Yast::WorkflowManager.AddWorkflow(:package, 0, "skelcd-control-SLES")
          Yast::WorkflowManager.MergeWorkflows
          Yast::WorkflowManager.RedrawWizardSteps
          # run new steps for product, for now disable back TODO: allow it
          res = Yast::ProductControl.RunFrom(Yast::ProductControl.CurrentStep + 1, false)
        end

        res
      end
    end
  end
end

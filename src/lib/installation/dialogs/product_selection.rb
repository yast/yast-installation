require "yast"

require "cwm/dialog"
require "installation/widgets/product_selector"

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
        # TODO: read real
        [
          ["sles", "SUSE Linux Enterprise Server"],
          ["sled", "SUSE Linux Enterprise Desktop"],
          ["openSUSE", "openSUSE Leap"],
          ["todo", "Ball Kicking Product"]
        ]
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
        end

        res
      end
    end
  end
end

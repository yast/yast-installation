require "yast"
require "cwm/widget"

Yast.import "ProductControl"

module Installation
  module Widgets
    # sets flag if online repositories dialog should be shown
    class OnlineReposCheckbox < CWM::CheckBox
      def initialize
        textdomain "installation"
      end

      def label
        _("Select Addiotional On-line Repositories")
      end

      def store
        # adjust work-flow according to value
        if value
          Yast::ProductControl.EnableModule("productsources")
        else
          Yast::ProductControl.DisableModule("productsources")
        end
      end
    end
  end
end

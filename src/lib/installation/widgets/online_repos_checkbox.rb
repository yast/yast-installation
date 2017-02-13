require "yast"
require "cwm/widget"

# add-on product holds also online repos
Yast.import "AddOnProduct"

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
        Yast::AddOnProduct.skip_add_ons = !value
      end
    end
  end
end

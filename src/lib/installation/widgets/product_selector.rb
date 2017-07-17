require "yast"

require "cwm/common_widgets"

module Installation
  module Widgets
    class ProductSelector < CWM::RadioButtons
      attr_reader :items

      # @param products [Array<string>] to display
      def initialize(products)
        @items = products
        textdomain "installation"
      end

      def hspacing
        1
      end

      def label
        _("Product to Install")
      end
    end
  end
end

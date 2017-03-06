require "yast"
require "cwm/widget"

module Installation
  module Widgets
    # sets flag if online repositories dialog should be shown
    class OnlineRepos < CWM::PushButton
      def initialize
        textdomain "installation"
      end

      def label
        _("Configure On-line Repositories")
      end

      def handle
        Yast::WFM.CallFunction("inst_productsources", [{ "script_called_from_another" => true }])

        :redraw
      end
    end
  end
end

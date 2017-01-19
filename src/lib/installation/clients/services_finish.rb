require "installation/finish_client"
require "installation/services"

module Installation
  module Clients
    class ServicesFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Adapting system services ...")
      end

      def write
        ::Installation::Services.write
      end
    end
  end
end

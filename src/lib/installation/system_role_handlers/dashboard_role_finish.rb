require "yast"
require "yast2/execute"

module Installation
  module SystemRoleHandlers
    class DashboardRoleFinish
      # Path to the activation script
      ACTIVATION_SCRIPT_PATH = "/usr/share/caasp-container-manifests/activate.sh".freeze

      # Run the activation script
      def run
        Yast::Execute.on_target(ACTIVATION_SCRIPT_PATH)
      end
    end
  end
end

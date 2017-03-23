require "yast"
Yast.import "Popup"
Yast.import "FileUtils"

module Installation
  module SystemRoleHandlers
    class DashboardRoleFinish
      include Yast::I18n
      include Yast::Logger

      # Path to the activation script
      ACTIVATION_SCRIPT_PATH = "/usr/share/caasp-container-manifests/activate.sh".freeze

      # Run the activation script
      def run
        if !Yast::FileUtils.Exists(ACTIVATION_SCRIPT_PATH)
          Yast::Popup.Error(_("Activation script not found:\n#{ACTIVATION_SCRIPT_PATH}"))
          return
        end

        out = Yast::SCR.Execute(Yast::Term.new(".target.bash_output"), ACTIVATION_SCRIPT_PATH)
        return if out["exit"].zero?

        Yast::Popup.LongError(out["stdout"])
      end
    end
  end
end

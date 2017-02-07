require "yast"
require "installation/widgets/system_role"
require "installation/widgets/online_repos_checkbox"
require "cwm/widget"

Yast.import "CWM"

module Installation
  # opensuse specific installation desktop selection dialog
  class DesktopRoles
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      textdomain "installation"

      # We do not need to create a wizard dialog in installation, but it's
      # helpful when testing all manually on a running system
      Yast::Wizard.CreateDialog if separate_wizard_needed?

      ret = Yast::CWM.show(
        content,
        caption: _("Computer Role")
      )

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      ret
    end

  private

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Yast::Mode.normal
    end

    def content
      VBox(
        Widgets::SystemRolesRadioButtons.new,
        Widgets::OnlineReposCheckbox.new
      )
    end
  end
end

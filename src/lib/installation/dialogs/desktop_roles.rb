require "yast"
require "installation/widgets/system_role"
require "cwm/widget"

Yast.import "CWM"
# add-on product holds also online repos
Yast.import "AddOnProduct"

module Installation

  # small widget implmenetation. Probably not worth reuse elsewhere
  class OnlineRepos < CWM::CheckBox
    def initialize
      textdomain "installation"
    end

    def label
      _("Add On-line Repositories Before Installation")
    end

    def store
      Yast::AddOnProduct.skip_add_ons = !value
    end
  end


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
        OnlineRepos.new
      )
    end
  end
end

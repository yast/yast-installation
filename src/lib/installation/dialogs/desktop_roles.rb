require "yast"
require "installation/widgets/system_role"
require "installation/widgets/online_repos"
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

      ret = nil
      loop do
        ret = Yast::CWM.show(
          content,
          caption:        _("Computer Role"),
          skip_store_for: [:redraw]
        )
        break if ret != :redraw
      end

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      # support passing addon as cmd argument, openQA use it for testing
      if Yast::Linuxrc.InstallInf("addon").nil?
        Yast::ProductControl.DisableModule("add-on")
      else
        Yast::ProductControl.EnableModule("add-on")
      end

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
        VSpacing(1),
        Left(Widgets::OnlineRepos.new)
      )
    end
  end
end

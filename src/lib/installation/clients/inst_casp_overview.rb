# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "users/widgets"
require "y2country/widgets"
require "ui/widgets"
require "tune/widgets"

require "installation/widgets/overview"
require "installation/widgets/system_role"
# FIXME: prototype only
require "installation/widgets/mocked"

module Installation
  # This library provides a simple dialog for setting
  # - the password for the system administrator (root)
  # - the keyboard layout
  # This dialog does not write the password to the system,
  # only stores it in UsersSimple module,
  # to be written during inst_finish.
  class InstCaspOverview
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      Yast.import "UI"
      Yast.import "Mode"
      Yast.import "CWM"

      textdomain "installation"

      # We do not need to create a wizard dialog in installation, but it's
      # helpful when testing all manually on a running system
      Yast::Wizard.CreateDialog if separate_wizard_needed?

      Yast::Wizard.SetTitleIcon("yast-users") # ?
      Yast::Wizard.EnableAbortButton

      # FIXME: where in the CaaSP workflow do we set the real thing?
      fake_release_notes = {
        # product name => notes (rich text)
        "CaaaaaaaSP!" => "<p>These are the <i>fake</i> release notes.</p>"
      }
      Yast::UI.SetReleaseNotes(fake_release_notes)
      # FIXME: This is copied from inst_complex_welcome
      # and may be superfluous here. We will find out once we integrate
      # this dialog in the workflow.
      Yast::Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")

      ret = nil
      loop do
        ret = Yast::CWM.show(
          content,
          # Title for installation overview dialog
          caption:        _("Installation Overview"),
          # Button label: start the installation
          next_button:    _("Install"),
          # do not show abort and back button
          abort_button:   "",
          back_button:    "",
          # do not store stuff when just redrawing
          skip_store_for: [:redraw]
        )
        break if ret != :redraw
      end

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      ret
    end

  private

    def quadrant_layout(upper_left:, lower_left:, upper_right:, lower_right:)
      HBox(
        HWeight(
          6,
          VBox(
            VWeight(5, upper_left),
            VStretch(),
            VWeight(5, lower_left)
          )
        ),
        HSpacing(3),
        HWeight(
          4,
          VBox(
            VWeight(5, upper_right),
            VStretch(),
            VWeight(5, lower_right)
          )
        )
      )
    end

    # Returns a UI widget-set for the dialog
    def content
      dashboard = Installation::Widgets::DashboardPlace.new
      quadrant_layout(
        upper_left: VBox(
          ::Widgets::RegistrationCode.new,
          ::Users::PasswordWidget.new(little_space: true),
          # use english us as default keyboard layout
          ::Y2Country::Widgets::KeyboardSelectionCombo.new("english-us")
        ),
        lower_left: VBox(
          Installation::Widgets::SystemRole.new(dashboard),
          dashboard,
          Tune::Widgets::SystemInformation.new
        ),
        upper_right: VBox(
          Installation::Widgets::Overview.new(client: "partitions_proposal"),
          Installation::Widgets::Overview.new(client: "bootloader_proposal")
        ),
        lower_right: VBox(
          Installation::Widgets::Overview.new(client: "network_proposal"),
          Installation::Widgets::Overview.new(client: "kdump_proposal")
        )
      )
    end

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Yast::Mode.normal
    end
  end
end

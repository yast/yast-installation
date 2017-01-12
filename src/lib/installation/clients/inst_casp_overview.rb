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

      Yast::Wizard.SetTitleIcon("yast-users")
      Yast::Wizard.EnableAbortButton

      ret = Yast::CWM.show(
        content,
        # Title for root-password dialogue
        caption: _("Installation Overview")
      )

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      ret
    end

  private

    # Returns a UI widget-set for the dialog
    def content
      VBox(
        VStretch(),
        # use english us as default keyboard layout
        ::Y2Country::Widgets::KeyboardSelection.new("english-us"),
        VSpacing(1),
        ::UI::Widgets::KeyboardLayoutTest.new,
        VStretch(),
        ::Users::PasswordWidget.new,
        VStretch(),
        Label("FIXME: add other widgets")
      )
    end

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Yast::Mode.normal
    end
  end
end

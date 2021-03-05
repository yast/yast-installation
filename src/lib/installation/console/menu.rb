# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

require "cwm"
require "cwm/dialog"

require "installation/console"
require "installation/console/menu_plugin"
require "installation/console/plugins"

Yast.import "Label"
Yast.import "Report"
Yast.import "UI"
Yast.import "Wizard"

module Installation
  module Console
    # the main dialog for configuring the installer
    #
    # testing in a running system:
    # Y2DIR=./src ruby -I src/lib -r installation/console/menu.rb -e \
    #  'Yast.ui_component="qt";Yast.import("Wizard");Yast::Wizard.CreateDialog; \
    #  ::Installation::Console::Menu.run'
    class Menu < CWM::Dialog
      def initialize
        textdomain "installation"
      end

      def title
        # TRANSLATORS: dialog title
        _("Configuration")
      end

      def run
        return nil unless can_start?

        loop do
          ret = super
          break if [:next, :back, :abort, :close].include?(ret)
        end
      end

      # the content of the dialog
      def contents
        # load the plugins
        Plugins.load_plugins

        # collect the plugin widgets
        widgets = MenuPlugin.widgets
        # insert a small spacing between the widgets depending on the list size,
        # no spacing in ncurses if there are too many widgets
        # (the size is rounded down to 0)
        spacing = widgets.size > 10 ? 0.4 : 1
        # this is a "join" for an Array...
        widgets = widgets.flat_map { |w| [w, VSpacing(spacing)] }.tap(&:pop)

        VBox(*widgets)
      end

      # show [OK] button
      def next_button
        Yast::Label.OKButton
      end

      # hide abort button
      def abort_button
        ""
      end

      # hide back button
      def back_button
        ""
      end

      # create a new Wizard dialog to hide the installation steps on the left side
      def should_open_dialog?
        true
      end

      def help
        _("<p>This is a special configuration menu which allows configuring " \
          "the system during installation or tweak some installation options.</p>")
      end

      # Is the toplevel dialog a wizard dialog? We cannot display the dialog
      # in Qt UI if a popup is currently displayed...
      def can_start?
        return true if Yast::UI.TextMode || Yast::Wizard.IsWizardDialog

        # TRANSLATORS: error message
        Yast::Report.Error(_("The installer configuration dialog cannot be displayed"\
          " when a popup window is visible.\nClose the popup first and then" \
          " repeat the action."))

        false
      end
    end
  end
end

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

require "yast"
require "ui/dialog"

module Installation
  # A subclass of UI::Dialog which provides a common dialog to edit an url. It
  # is composed by two buttons to confirm and cancel the edition, a dialog
  # heading and a help text.
  #
  # @example simple url location dialog
  #
  #   class ExampleURLDialog < UI::URLDialog
  #     def entry_label
  #       "Example URL"
  #     end
  #   end
  class URLDialog < UI::Dialog
    include Yast::I18n
    include Yast::UIShortcuts

    attr_accessor :url

    # Constructor
    #
    # The dialog text entry will be filled with the url given
    #
    # @param url [String]
    def initialize(url)
      @url = url
    end

    # Shows a dialog when the given url is wrong
    #
    # @param [String] original Original value
    # @return [String] new value
    def dialog_content
      VBox(
        show_heading? ? Heading(dialog_title) : Empty(),
        show_help? ? RichText(help_text) : Empty(),
        VSpacing(1),
        VStretch(),
        MinWidth(60,
          Left(TextEntry(Id(:uri), entry_label, @url))),
        VSpacing(1),
        VStretch(),
        HBox(
          PushButton(Id(:ok), Opt(:default), ok_label),
          PushButton(Id(:cancel), cancel_label)
        )
      )
    end

    # Handler for the :ok button which queries the value of the URL entry and
    # finish the dialog returning the value of it
    #
    # @return  [String] the value of the url text entry
    def ok_handler
      @url = Yast::UI.QueryWidget(Id(:uri), :Value)
      finish_dialog(@url)
    end

    # Handler for the :cancel button wich finishes the dialog and returns :cancel
    #
    # @return [Symbol] :cancel
    def cancel_handler
      finish_dialog(:cancel)
    end

    def ok_label
      Yast::Label.OKButton
    end

    def cancel_label
      Yast::Label.CancelButton
    end

    # Help text that will be displayed above the url entry
    #
    # @return [String]
    def help_text
      ""
    end

    # Heading title for the dialog
    #
    # @return [String]
    def dialog_title
      ""
    end

    # Text label for the url entry
    #
    # @return [String]
    def entry_label
      ""
    end

  private

    # Determines wether the help text is shown
    #
    # @return [Boolean] true if the help text is not empty
    #
    # @see help_text
    def show_help?
      return true if !help_text.empty?

      false
    end

    # Determines wether the dialog title is shown
    #
    # @return [Boolean] true if the dialog title is not empty
    #
    # @see dialog_title
    def show_heading?
      return true if !dialog_title.empty?

      false
    end

  end
end

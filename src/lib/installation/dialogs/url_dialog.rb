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

# FIXME: move to yast2
# (This dialog is based in ProfileSourceDialog)
module Installation
  class URLDialog < UI::Dialog
    include Yast::I18n
    include Yast::UIShortcuts

    attr_accessor :url

    def initialize(url)
      @url = url
    end

    # Shows a dialog when the given url is wrong
    #
    # @param [String] original Original value
    # @return [String] new value
    def dialog_content
      HBox(
        HWeight(30, RichText(help_text)),
        HStretch(),
        HSpacing(1),
        HWeight(
          70,
          VBox(
            Heading(dialog_title),
            VSpacing(1),
            VStretch(),
            MinWidth(60,
              Left(TextEntry(Id(:uri), entry_label, @url))),
            VSpacing(1),
            VStretch(),
            HBox(
              PushButton(Id(:retry), Opt(:default), Yast::Label.RetryButton),
              PushButton(Id(:abort), Yast::Label.AbortButton)
            )
          )
        )
      )
    end

    def retry_handler
      @url = Yast::UI.QueryWidget(Id(:uri), :Value)
      finish_dialog(@url)
    end

    def abort_handler
      finish_dialog(:abort)
    end

    # Help text that will be displayed at the left of the dialog
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
  end
end

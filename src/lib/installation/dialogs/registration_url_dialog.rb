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
require "installation/dialogs/url_dialog"

module Installation
  class RegistrationURLDialog < ::Installation::URLDialog
    def initialize(*args)
      textdomain "installation"
      super
    end

    def help_text
      # TRANSLATORS: Help text alerting the user about a invalid url
      _("<p>\n" \
        "The registration URL provided in the command line is not valid.\n" \
        "Check that you entered it correctly and try again.\n" \
        "</p>")
    end

    def entry_label
      _("Registration URL")
    end

    def dialog_title
      _("Registration URL")
    end
  end
end

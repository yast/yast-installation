# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2013 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
#
# Summary: Ask user for the SCC credentials
#

module Yast
  class InstSccClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Popup"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"
      Yast.import "Report"

      @test_mode = WFM.Args.include?("test")

      Wizard.CreateDialog if @test_mode

      show_scc_credentials_dialog

      ret = nil
      email = nil
      reg_code = nil

      continue_buttons = [:next, :back, :close, :abort]
      while !continue_buttons.include?(ret) do
        ret = UI.UserInput

        if ret == :next
          email = UI.QueryWidget(Id(:email), :Value)
          reg_code = UI.QueryWidget(Id(:reg_code), :Value)

          # TODO: validate the email and the reg_key ?? How to skip registration then?
          #if email.empty?
          #  Popup.Error(_("The email address cannot be empty."))
          #  ret = nil
          #end
        end
      end

      if ret == :next && email && reg_code
        Popup.ShowFeedback(_("Sending Data"), _("Contacting the SUSE Customer Center server..."))

        # TODO: connect to the SCC server here
        sleep(7)

        Popup.ClearFeedback
      end

      Wizard.CloseDialog if @test_mode

      return ret
    end


    private

    def scc_credentials_dialog
      Frame(_("SUSE Customer Center Credentials"),
        MarginBox(1, 0.5,
          VBox(
            InputField(Id(:email), _("&Email")),
            VSpacing(0.5),
            InputField(Id(:reg_code), _("Registration &Code"))
          )
        )
      )
    end

    def scc_help_text
      # TODO: improve the help text
      _("Enter SUSE Customer Center credentials here to register the system to get updates and add-on products.")
    end

    def show_scc_credentials_dialog
      Wizard.SetContents(
        _("SUSE Customer Center Registration"),
        scc_credentials_dialog,
        scc_help_text,
        GetInstArgs.enable_back || @test_mode,
        GetInstArgs.enable_next || @test_mode
      )
    end
  end
end

Yast::InstSccClient.new.main

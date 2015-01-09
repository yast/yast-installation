# encoding: utf-8

# Module:	inst_info.ycp
#
# Authors:	Arvin Schnell <arvin@suse.de>
#
# Purpose:	Show info in existent.
#
# $Id$
module Yast
  class InstTestWorkflowClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Wizard"
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"

      @args = GetInstArgs.argmap

      @caption = Ops.add("Client: ", Ops.get_string(@args, "step_name", "none"))
      @help = "Nothing here"

      @contents = VBox(
        Label(Ops.add("id: ", Ops.get_string(@args, "step_id", "none")))
      )

      # Wizard::SetContents (caption, contents, help, GetInstArgs::enable_back(), GetInstArgs::enable_next());
      Wizard.SetContents(@caption, @contents, @help, true, true)

      @button = Convert.to_symbol(UI.UserInput)

      @button
    end
  end
end

Yast::InstTestWorkflowClient.new.main

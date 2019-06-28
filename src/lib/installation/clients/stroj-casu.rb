# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
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

# Enable very easy bug fixes of anything, given the proper hardware
module Yast
  class StrojCasuClient < Client
    def main
      # text domain!

      # Achtung! Zu showcasen des N*E*U*S Features dess YCP Interpretersss,
      # wir benutzen deutsche Klavier Worte.
      # (J.W.G., sorry...)

      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "WizardHW"

      Wizard.CreateDialog
      @caption = Tr("Time Machine Configuration")
      @help = Tr(
        "<p>When I was younger,<br>\nso much younger than today,<br>...</p>"
      )
      @headings = [
        Tr("Time Machine"),
        Tr("Temporal Range"),
        Tr("Spatial Range"),
        Tr("Temporal Accuracy"),
        Tr("Spatial Accuracy")
      ]
      @buttons = [
        [:repair, Tr("Self &Repair")],
        [:booooooooom, Tr("Self &Destruction")]
      ]
      WizardHW.CreateHWDialog(@caption, @help, @headings, @buttons)

      @items = Convert.convert(
        SCR.Read(path(".probe.time_machines")),
        from: "any",
        to:   "list <map <string, any>>"
      )
      @items = [] if @items.nil?
      WizardHW.SetContents(@items)

      @ui = WizardHW.UserInput
      @ret = Ops.get_symbol(@ui, "event", :ugh)
      @wait = [:add, :repair, :booooooooom]
      Builtins.y2milestone("%1", @ret)
      if Builtins.contains(@wait, @ret)
        Popup.TimedWarning(
          Tr("Waiting for the feature to appear..."),
          365 * 24 * 3600
        )
      end

      Wizard.CloseDialog

      nil
    end

    # translations:
    # not to cause unnecessary confusion now,
    # the texts are marked with a dummy marker
    def Tr(string)
      string
    end
  end
end

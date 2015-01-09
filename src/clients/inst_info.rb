# encoding: utf-8

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

# Module:	inst_info.ycp
#
# Authors:	Arvin Schnell <arvin@suse.de>
#
# Purpose:	Show info in existent.
#
# $Id$
module Yast
  class InstInfoClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "Report"

      @infofile = "/info.txt" # copied there by linuxrc
      @infotext = Convert.to_string(
        SCR.Read(path(".target.string"), [@infofile, ""])
      )

      if @infotext != ""
        @tmp1 = Report.Export
        @tmp2 = Ops.get_map(@tmp1, "messages", {})
        @timeout_seconds = Ops.get_integer(@tmp2, "timeout", 0)

        UI.OpenDialog(
          HBox(
            VSpacing(22), # force height to 22/25 of screen height
            VBox(
              HSpacing(78), # force width to 78/80 of screen width
              VSpacing(0.2),
              RichText(Opt(:plainText), @infotext),
              ReplacePoint(Id(:rp1), Empty()),
              HBox(
                HStretch(),
                # Button to accept a license agreement
                HWeight(
                  1,
                  PushButton(Id(:accept), Opt(:default), _("I &Agree"))
                ),
                HStretch(),
                # Button to reject a license agreement
                HWeight(1, PushButton(Id(:donotaccept), _("I Do &Not Agree"))),
                HStretch(),
                ReplacePoint(Id(:rp2), Empty())
              )
            )
          )
        )

        UI.SetFocus(Id(:accept))

        @info_ret = :empty

        if @timeout_seconds == 0
          @info_ret = Convert.to_symbol(UI.UserInput)
        else
          UI.ReplaceWidget(
            Id(:rp1),
            Label(Id(:remaining_time), Ops.add("", @timeout_seconds))
          )
          UI.ReplaceWidget(Id(:rp2), PushButton(Id(:stop), Label.StopButton))

          while Ops.greater_than(@timeout_seconds, 0)
            Builtins.sleep(1000)
            @info_ret = Convert.to_symbol(UI.PollInput)
            break if @info_ret == :accept || @info_ret == :donotaccept
            if @info_ret == :stop
              while @info_ret == :stop
                @info_ret = Convert.to_symbol(UI.UserInput)
              end
              break
            end
            @info_ret = :accept
            @timeout_seconds = Ops.subtract(@timeout_seconds, 1)
            UI.ChangeWidget(
              Id(:remaining_time),
              :Value,
              Ops.add("", @timeout_seconds)
            )
          end
        end

        UI.CloseDialog

        if @info_ret != :accept
          Builtins.y2milestone("user didn't accept info.txt")

          # tell linuxrc that we aborted
          Linuxrc.WriteYaSTInf( "Aborted" => "1" )
          return :abort
        end
      end

      :auto
    end
  end
end

Yast::InstInfoClient.new.main

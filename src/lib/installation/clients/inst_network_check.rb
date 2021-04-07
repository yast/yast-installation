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
module Yast
  class InstNetworkCheckClient < Client
    def main
      Yast.import "UI"
      #
      # Authors:	Lukas Ocilka <locilka@suse.cz>
      #
      # Purpose:	This script detects whether there is no active network.
      #		In such case, user can configure network manually.
      #		This should be used in the first stage installation.
      #
      # See More:	FATE #301967
      #
      # $Id$
      #

      textdomain "installation"

      Yast.import "NetworkService"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "GetInstArgs"
      Yast.import "Directory"
      Yast.import "Icon"

      @enable_next = true
      @enable_back = true

      # Script can be called with some arguments
      #
      #
      # **Structure:**
      #
      #     [$[
      #        "dontskip" : true, // do not skipt the dialog even if network is configured
      #      ]]
      @argmap = GetInstArgs.argmap
      Builtins.y2milestone("Script args: %1", @argmap)

      # We don't need to run this script to setup the network
      # If some network is already running...
      if NetworkService.isNetworkRunning
        if Ops.get_boolean(@argmap, "dontskip", false) == true
          Builtins.y2milestone(
            "Network is already running, not skipping (forced)..."
          )
        else
          Builtins.y2milestone("Network is already running, skipping...")
          return :next
        end
      else
        Builtins.y2milestone(
          "No network configuration found, offering to set it up..."
        )
      end

      @displayinfo = UI.GetDisplayInfo
      @supports_images = Ops.get_boolean(@displayinfo, "HasImageSupport", false)

      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Network Setup"),
        VBox(
          VStretch(),
          RadioButtonGroup(
            Id("to_do_a_network_setup_or_not_to_do"),
            HBox(
              HStretch(),
              VBox(
                # TRANSLATORS: dialog label
                HBox(
                  @supports_images ? HBox(Icon.Simple("warning"), HSpacing(2)) : Empty(),
                  Left(
                    Label(
                      _(
                        "No network setup has been found.\n" \
                          "It is important if using remote repositories,\n" \
                          "otherwise you can safely skip it.\n"
                      )
                    )
                  )
                ),
                VSpacing(2),
                # TRANSLATORS: dialog label
                Left(Label(_("Configure your network card now?"))),
                VSpacing(1),
                Frame(
                  # TRANSLATORS: frame label
                  _("Select"),
                  MarginBox(
                    1.5,
                    1,
                    VBox(
                      # TRANSLATORS: radio button
                      Left(
                        RadioButton(
                          Id("yes_do_run_setup"),
                          _("&Yes, Run the Network Setup"),
                          true
                        )
                      ),
                      # TRANSLATORS: radio button
                      Left(
                        RadioButton(
                          Id("no_do_not_run_setup"),
                          _("No, &Skip the Network Setup")
                        )
                      )
                    )
                  )
                )
              ),
              HStretch()
            )
          ),
          VStretch()
        ),
        # TRANSLATORS: help text, part 1/2
        _(
          "<p>The current installation system does not\nhave a configured network.</p>\n"
        ) +
          # TRANSLATORS: help text, part 2/2
          _(
            "<p>A configured network is needed for using remote repositories\nor add-on products. If you do not use remote repositories, skip the configuration.</p>\n"
          ),
        @enable_next,
        @enable_back
      )

      @ret = nil

      @run_setup = nil

      @return_this = :next

      loop do
        @ret = UI.UserInput

        if @ret == :next
          @option_selected = Convert.to_string(
            UI.QueryWidget(
              Id("to_do_a_network_setup_or_not_to_do"),
              :CurrentButton
            )
          )
          Builtins.y2milestone("Network setup? %1", @option_selected)

          # run net setup
          if @option_selected == "yes_do_run_setup"
            Builtins.y2milestone("Running inst_lan")
            @ret2 = WFM.call(
              "inst_lan",
              [GetInstArgs.argmap.merge("skip_detection" => true), "hide_abort_button" => true]
            )
            Builtins.y2milestone("inst_lan ret: %1", @ret2)

            # everything went fine
            if @ret2 == :next
              @return_this = :next
              break
              # something wrong or aborted
            else
              if @ret2.nil?
                # error popup
                Popup.Message(
                  Builtins.sformat(
                    _(
                      "Network configuration has failed.\nCheck the log file %1 for details."
                    ),
                    Ops.add(Directory.logdir, "/y2log")
                  )
                )
              end
              UI.ChangeWidget(
                Id("to_do_a_network_setup_or_not_to_do"),
                :CurrentButton,
                "no_do_not_run_setup"
              )
              next
            end

            # skip net setup
          else
            Builtins.y2milestone("Skipping network setup")
            @return_this = :next
            break
          end
        elsif @ret == :back
          Builtins.y2milestone("Going back")
          @return_this = :back
          break
        elsif @ret == :abort
          if Popup.ConfirmAbort(:painless)
            @return_this = :abort
            break
          end
        else
          Builtins.y2error("Unknown ret: %1", @ret)
        end
      end

      @return_this

      # EOF
    end
  end
end

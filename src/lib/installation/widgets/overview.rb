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
require "cwm/widget"

Yast.import "Popup"

module Y2Caasp
  module Widgets
    # A widget for an all-in-one installation dialog.
    # It uses the `simple_mode` of {Installation::ProposalClient#make_proposal}
    # It is immutable, so for showing new values reinitialize widget
    class Overview < CWM::CustomWidget
      attr_reader :proposal_client

      # @param client [String] A proposal client implementing simple_mode,
      # @param redraw [Array<Overview>] list of other Overview clients. In case
      # of :redraw action every of these clients will be redrawn too. Caller is
      # responsible for not creating circular dependencies.
      #   eg. "bootloader_proposal"
      def initialize(client:, redraw: [])
        textdomain "installation"
        @proposal_client = client
        @replace_point = "rp_" + client
        # by default widget_id is the class name; must differentiate instances
        self.widget_id = "overview_" + client
        @blocking = false
        @overviews_for_redraw = redraw
      end

      def contents
        ReplacePoint(Id(@replace_point), widget)
      end

      def label
        return @label if @label

        d = Yast::WFM.CallFunction(proposal_client, ["Description", {}])
        @label = d["menu_title"]
      end

      def items
        return @items if @items

        d = Yast::WFM.CallFunction(proposal_client,
          [
            "MakeProposal",
            { "simple_mode" => true }
          ])
        if d["warning"] && !d["warning"].empty? && d["warning_level"] != :notice
          Yast::Popup.LongError(
            format(
              _("Problem found when proposing %{client}:<br>" \
              "Severity: %{severity}<br>" \
              "Message: %{message}"),
              client:   label.delete("&"),
              severity: (d["warning_level"] || :warning).to_s,
              message:  d["warning"]
            )
          )
          @blocking = [:blocker, :fatal].include?(d["warning_level"])
        else
          @blocking = false
        end
        @items = d["label_proposal"]
      end

      # Updates overview content
      def redraw
        reset

        Yast::UI.ReplaceWidget(Id(@replace_point), widget)

        @overviews_for_redraw.each(&:redraw)
      end

      # Custom event handler
      def handle(_event)
        Yast::WFM.CallFunction(proposal_client, ["AskUser", {}])

        redraw

        nil
      end

      def validate
        return true unless @blocking

        # %s is a heading of a problematic section, like "Partitioning" or "Network"
        Yast::Popup.Error(
          _("%s blocks the installation. Please solve the problem there before proceeding.") %
          label.delete("&")
        )

        false
      end

    private

      def button_id
        # an arbitrary unique id
        "ask_" + proposal_client
      end

      # The overview representation in common UI widgets
      def widget
        VBox(
          Left(PushButton(Id(button_id), label)),
          * items.map { |i| Left(Label(" * #{i}")) }
        )
      end

      # Flush cache(s)
      def reset
        @label = nil
        @items = nil
      end
    end
  end
end

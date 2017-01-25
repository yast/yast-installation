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

module Installation
  module Widgets
    # A widget for an all-in-one installation dialog.
    # It uses the `simple_mode` of {Installation::ProposalClient#make_proposal}
    class Overview < CWM::CustomWidget
      attr_reader :proposal_client

      # @param client [String] A proposal client implementing simple_mode,
      #   eg. "bootloader_proposal"
      def initialize(client:)
        @proposal_client = client
      end

      def contents
        VBox(
          Left(PushButton(Id(button_id), label)),
          * items.map { |i| Left(Label(" * #{i}")) }
        )
      end

      def label
        d = Yast::WFM.CallFunction(proposal_client, ["Description", {}])
        d["menu_title"]
      end

      def items
        d = Yast::WFM.CallFunction(proposal_client,
                                   [
                                     "MakeProposal",
                                     {"simple_mode" => true}
                                   ])
        d["label_proposal"]
      end

      def handle(_event)
        Yast::WFM.CallFunction(proposal_client, ["AskUser", {}])
        :redraw
      end

      private

      def button_id
        # an arbitrary unique id
        "ask_" + proposal_client
      end
    end

    class PartitioningOverview < Overview
      def initialize
        super(client: "partitions_proposal")
      end
    end

    class BootloaderOverview < Overview
      def initialize
        super(client: "bootloader_proposal")
      end
    end

    class NetworkOverview < Overview
      def initialize
        super(client: "network_proposal")
      end
    end

    class KdumpOverview < Overview
      def initialize
        super(client: "kdump_proposal")
      end
    end

    class InvisibleSoftwareOverview < Overview
      def initialize
        super(client: "software_proposal")
      end

      def contents
        _ = items
        Empty()
      end
    end
  end
end

# encoding: utf-8

# Module:		proposal_dummy.ycp
#
# $Id$
#
# Author:		Stefan Hundhammer <sh@suse.de>
#
# Purpose:		Proposal function dispatcher - dummy version.
#			Use this as a template for other proposal dispatchers.
#			Don't forget to replace all fixed values with real values!
#
#			See also file proposal-API.txt for details.
module Yast
  class DummyProposalClient < Client
    def main
      textdomain "installation"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        @language_changed = Ops.get_boolean(@param, "language_changed", false)

        # call some function that makes a proposal here:
        #
        # DummyMod::MakeProposal( force_reset );

        # Fill return map

        @ret = {
          "raw_proposal"  => [
            "proposal item #1",
            "proposal item #2",
            "proposal item #3"
          ],
          "warning"       => "This is just a dummy proposal!",
          "warning_level" => :blocker
        }
      elsif @func == "AskUser"
        @has_next = Ops.get_boolean(@param, "has_next", false)

        # call some function that displays a user dialog
        # or a sequence of dialogs here:
        #
        # sequence = DummyMod::AskUser( has_next );

        # Fill return map

        @ret = { "workflow_sequence" => :next }
      elsif @func == "Description"
        # Fill return map.
        #
        # Static values do just nicely here, no need to call a function.

        @ret = {
          # this is a heading
          "rich_text_title" => _("Dummy"),
          # this is a menu entry
          "menu_title"      => _("&Dummy"),
          "id"              => "dummy_stuff"
        }
      elsif @func == "Write"
        # Fill return map.
        #

        @ret = { "success" => true }
      end

      deep_copy(@ret)
    end
  end
end

Yast::DummyProposalClient.new.main

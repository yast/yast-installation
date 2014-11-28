# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2014 Novell, Inc. All Rights Reserved.
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

require "yast"

module Installation
  # Stores various proposals clients and provides metadata about them
  class ProposalStore
    def initialize(proposal_mode)
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "Stage"

      @proposal_mode = proposal_mode
    end

    def can_be_skipped?
      return @can_skip unless @can_skip.nil?

      if properties.key?("enable_skip")
        @can_skip = properties["enable_skip"]
      else
        @can_skip = !["initial", "uml"].include?(@proposal_mode)
      end

      @can_skip
    end

    def has_tabs?
      properties.key?("proposal_tabs")
    end

    def proposals_names
      return @proposal_names if @proposal_names

      @proposal_names = Yast::ProductControl.getProposals(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )

      @proposal_names.map!(&:first) # first element is name of client

      # FIXME: is it still used?
      # in normal mode we don't want to switch between installation and update
      @proposal_names.delete("mode_proposal") if Yast::Mode.normal

      @proposal_names
    end

    # returns single list of modules presentation order or list of tabs with list of modules
    def presentation_order
      return @modules_order if @modules_order

      if has_tabs?
        @modules_order = properties["proposal_tabs"]
        @modules_order.each do |module_tab|
          module_tab.map! do |mod|
            mod.include?("_proposal") ? mod : mod + "_proposal"
          end
        end
      else
        @modules_order = Yast::ProductControl.getProposals(
          Yast::Stage.stage,
          Yast::Mode.mode,
          @proposal_mode
        )

        @modules_order.sort_by! { |m| m[1] || 50 } # second element is presentation order

        @modules_order.map!(&:first)
      end

      @modules_order
    end

  private

    def properties
      @proposal_properties ||= Yast::ProductControl.getProposalProperties(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )
    end
  end
end

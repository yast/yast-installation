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
    include Yast::Logger
    include Yast::I18n

    def initialize(proposal_mode)
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "Stage"

      textdomain "installation"

      @proposal_mode = proposal_mode

    end

    def headline
      if properties["label"]
        Yast::Builtins.dgettext(
          Yast::ProductControl.getProposalTextDomain,
          properties["label"]
        )
      else
        _("Installation Overview")
      end
    end

    def icon
      case @proposal_mode
      when "network"
        "yast-network"
      when "hardware"
        "yast-controller"
      else
        properties["icon"] || "yast-software"
      end
    end

    def help_text(current_tab: nil, locked_modules: false)
      # General part of the help text for all types of proposals
      how_to_change = _(
        "<p>\n" +
          "Change the values by clicking on the respective headline\n" +
          "or by using the <b>Change...</b> menu.\n" +
          "</p>\n"
      )

      # Help text for installation proposal, continued
      not_modified = _(
        "<p>\n" +
          "Your hard disk has not been modified yet. You can still safely abort.\n" +
          "</p>\n"
      )

      global_help = case @proposal_mode
      when "initial"
        if Yast::Mode.installation
          # Help text for installation proposal
          # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" +
              "Select <b>Install</b> to perform a new installation with the values displayed.\n" +
              "</p>\n"
            )
        else # so update
        # Help text for update proposal
        # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" +
              "Select <b>Update</b> to perform an update with the values displayed.\n" +
              "</p>\n"
          )
        end
      when "network"
        # Help text for network configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" +
            "Put the network settings into effect by pressing <b>Next</b>.\n" +
            "</p>\n"
        )
      when "service"
        # Help text for service configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" +
            "Put the service settings into effect by pressing <b>Next</b>.\n" +
            "</p>\n"
        )
      when "hardware"
        # Help text for hardware configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" +
            "Put the hardware settings into effect by pressing <b>Next</b>.\n" +
            "</p>\n"
        )
      when "uml"
        # Proposal in uml module
        _("<P><B>UML Installation Proposal</B></P>") +
          # help text
          _(
            "<P>UML (User Mode Linux) installation allows you to start independent\nLinux virtual machines in the host system.</P>"
          )
      else
        if properties["help"] && !properties["help"].empty?
          # Proposal help from control file module
          Yast::Builtins.dgettext(
            Yast::ProductControl.getProposalTextDomain,
            Yast::Ops.get_string(@proposal_properties, "help", "")
          )
        else
          # Generic help text for other proposals (not basic installation or
          # hardhware configuration.
          # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" +
              "To use the settings as displayed, press <b>Next</b>.\n" +
              "</p>\n"
          )
        end
      end

      help_text = global_help + how_to_change
      help_text += not_modified if @proposal_mode == "initial"

      if locked_modules
        # help text
        help_text << _(
          "<p>Some proposals might be\n" +
            "locked by the system administrator and therefore cannot be changed. If a\n" +
            "locked proposal needs to be changed, ask your system administrator.</p>\n"
        )
      end

      modules_order = presentation_order
      modules_order = modules_order[current_tab] if has_tabs?


      modules_order.each_with_object(help_text) do |client, text|
        next unless descriptions[client]["help"]
        next if descriptions[client]["help"].empty?

        text << descriptions[client]["help"]
      end

      help_text
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

    def tab_labels
      return @tab_labels if @tab_labels

      raise "Invalid call to tab_labels for proposal without tabs" unless has_tabs?


      tabs = properties["proposal_tabs"]
      @tab_labels = tabs.map { |m| m["label"] || "Tab" }
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

      # FIXME add filter to only installed clients
      @proposal_names
    end

    # returns single list of modules presentation order or list of tabs with list of modules
    def presentation_order
      return @modules_order if @modules_order

      if has_tabs?
        @modules_order = properties["proposal_tabs"]
        @modules_order.map! { |m| m["proposal_modules"] }

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

    # Makes proposal for all proposal clients.
    def make_proposals(force_reset: false, language_changed: false)
      # TODO: callbacks to show partial proposals
      @link2submod = {}

      proposal_names.each do |submod|
        proposal_map = make_proposal(submod, force_reset: force_reset,
          language_changed: language_changed)

        # update link map
        (proposal_map["links"] || []).each do |link|
          @link2submod[link] = submod
        end

        if proposal_map["language_changed"]
          # TODO: callback to notice, that we need to retranslate UI
          @descriptions = nil # invalid descriptions cache
          return make_proposals(force_reset: force_reset, language_changed: true)
        end

        break if proposal_map["warning_level"] == :fatal
      end
    end

    def descriptions
      return @descriptions if @descriptions

      missing_no = 1
      @id_mapping = {}
      @descriptions = proposal_names.each_with_object({}) do |client, res|
        description = description_for(client)
        if !description["id"]
          log.warn "proposal client #{client} missing key 'id' in #{description}"

          description["id"] = "module_#{missing_no}"
          missing_no += 1
        end

        @id_mapping[description["id"]] = client

        res[client] = description
      end
    end

    def id_for(client)
      descriptions[client]["id"]
    end

    def title_for(client)
      descriptions[client]["rich_text_title"] ||
        descriptions[client]["rich_text_raw_title"] ||
        client
    end

    def handle_link(link)
      client = @id_mapping[link]
      client ||= @link2submod[link]

      if !client
        log.error "unknown link #{link}. Broken proposal client?"
        return nil
      end

      data = {
        "has_next"  => false,
        "chosen_id" => link
      }

      Yast::WFM.CallFunction(client, ["AskUser", data])
    end

  private

    def properties
      @proposal_properties ||= Yast::ProductControl.getProposalProperties(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )
    end

    def make_proposal(client, force_reset: false, language_changed: false)
      proposal = Yast::WFM.CallFunction(
        client,
        [
          "MakeProposal",
          {
            "force_reset"      => force_reset,
            "language_changed" => language_changed
          }
        ]
      )

      log.debug "#{client} MakeProposal() returns #{proposal}"

      proposal
    end
  end
end

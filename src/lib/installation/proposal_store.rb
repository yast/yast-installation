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
  # 1. Provides access to metadata of proposal parts (clients), as defined in the control file elements
  # /productDefines/proposals/proposal: https://github.com/yast/yast-installation-control/blob/master/control/control.rnc
  # 2. Handles all calls to the parts (clients).
  class ProposalStore
    include Yast::Logger
    include Yast::I18n

    # How many times to maximally (re)run the proposal while some proposal clients
    # try to re-trigger their run again, number includes their initial run
    # and resets before each proposal loop starts
    MAX_LOOPS_IN_PROPOSAL = 8

    # @param [String] proposal_mode one of initial, service, network, hardware,
    #   uml, ... or anything else
    def initialize(proposal_mode)
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "Stage"

      textdomain "installation"

      @proposal_mode = proposal_mode
    end

    # @return [String] translated headline
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

    # @return [String] like "yast-foo"
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

    # @return [String] Richtext, the complete help text: a common intro + all
    #   individual parts.
    def help_text(current_tab = nil)
      # General part of the help text for all types of proposals
      how_to_change = _(
        "<p>\n" \
          "Change the values by clicking on the respective headline\n" \
          "or by using the <b>Change...</b> menu.\n" \
          "</p>\n"
      )

      # Help text for installation proposal, continued
      not_modified = _(
        "<p>\n" \
          "Your hard disk has not been modified yet. You can still safely abort.\n" \
          "</p>\n"
      )

      help_text = global_help + how_to_change
      help_text += not_modified if @proposal_mode == "initial"

      help_text << modules_help(current_tab)

      help_text
    end

    def can_be_skipped?
      return @can_skip unless @can_skip.nil?

      if properties.key?("enable_skip")
        @can_skip = properties["enable_skip"] == "yes"
      else
        @can_skip = !["initial", "uml"].include?(@proposal_mode)
      end

      @can_skip
    end

    def tabs?
      properties.key?("proposal_tabs")
    end

    # @return [Array<String>] translated tab labels
    # @raise [RuntimeError] if used in proposal without tabs
    def tab_labels
      return @tab_labels if @tab_labels

      raise "Invalid call to tab_labels for proposal without tabs" unless tabs?

      tabs = properties["proposal_tabs"]
      @tab_labels = tabs.map { |m| m["label"] }
    end

    # @return [Array<String>] proposal names in execution order, including
    #    the "_proposal" suffix
    def proposal_names
      return @proposal_names if @proposal_names

      @proposal_names = Yast::ProductControl.getProposals(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )

      @proposal_names.map!(&:first) # first element is name of client

      missing_proposals = @proposal_names.reject { |proposal| Yast::WFM::ClientExists(proposal) }
      unless missing_proposals.empty?
        log.warn "These proposals are missing on system: #{missing_proposals}"
      end

      # Filter missing proposals out
      @proposal_names -= missing_proposals
    end

    # returns single list of modules presentation order or list of tabs with list of modules
    def presentation_order
      return @modules_order if @modules_order

      tabs? ? order_with_tabs : order_without_tabs
    end

    # Makes proposal for all proposal clients.
    # @param callback Called after each client/part, to report progress. Gets
    #   part name and part result as arguments
    def make_proposals(force_reset: false, language_changed: false, callback: proc {})
      clear_triggers
      clear_proposals_counter

      # At first run, all clients will be called
      call_proposals = proposal_names
      log.info "Proposals to call: #{call_proposals}"

      loop do
        call_proposals.each do |client|
          description_map = make_proposal(client, force_reset: force_reset,
            language_changed: language_changed, callback: callback)

          break unless parse_description_map(client, description_map, force_reset, callback)
        end

        # Second and next runs: only triggered clients will be called
        call_proposals = proposal_names.select { |client| should_be_called_again?(client) }

        break if call_proposals.empty?
        log.info "These proposals want to be called again: #{call_proposals}"

        unless should_run_proposals_again?(call_proposals)
          log.warn "Too many loops in proposal, exiting"
          break
        end
      end

      log.info "Making proposals have finished"
    end

    # Calls a given client/part to retrieve their description
    # @return [Hash] with keys "id", "menu_title" "rich_text_title"
    # @see http://www.rubydoc.info/github/yast/yast-yast2/Installation/ProposalClient:description
    def description_for(client)
      @descriptions ||= {}
      return @descriptions[client] if @descriptions.key?(client)

      description = Yast::WFM.CallFunction(client, ["Description", {}])

      unless description.key?("id")
        log.warn "proposal client #{client} is missing key 'id' in #{description}"
        @missing_no ||= 1
        description["id"] = "module_#{@missing_no}"
        @missing_no += 1
      end

      @descriptions[client] = description
    end

    # Returns all currently cached client descriptions
    #
    # @return [Hash] with descriptions
    def descriptions
      @descriptions ||= {}
    end

    # Returns ID for given client
    #
    # @return [String] an id provided by the description API
    def id_for(client)
      description_for(client).fetch("id", client)
    end

    # Returns UI title for given client
    #
    # @param [String] client
    # @return [String] a title provided by the description API
    def title_for(client)
      description = description_for(client)

      description["rich_text_title"] ||
        description["rich_text_raw_title"] ||
        client
    end

    # Calls client('AskUser'), to change a setting interactively (if link is the
    # heading for the part) or noninteractively (if it is a "shortcut")
    def handle_link(link)
      client = client_for_link(link)

      data = {
        "has_next"  => false,
        "chosen_id" => link
      }

      Yast::WFM.CallFunction(client, ["AskUser", data])
    end

    # Returns client name that handles the given link returned by UI,
    # returns nil if link is unknown.
    # Link can be either the client ID or a shortcut link.
    #
    # @param [String] link
    # @return [String] client name
    def client_for_link(link)
      raise "There are no client descriptions known, call 'client(Description)' first" if @descriptions.nil?

      matching_client = @descriptions.find do |_client, description|
        description["id"] == link || description.fetch("links", []).include?(link)
      end

      raise "Unknown user request #{link}. Broken proposal client?" if matching_client.nil?

      matching_client.first
    end

  private

    # Evaluates the given description map, and handles all the events
    # by returning whether to continue in the current proposal loop
    # Also stores triggers for later use
    #
    # @return [Boolean] whether to continue with iteration over proposals
    def parse_description_map(client, description_map, force_reset, callback)
      raise "Invalid proposal from client #{client}" if description_map.nil?

      if description_map["warning_level"] == :fatal
        log.error "There is an error in the proposal"
        return false
      end

      if description_map["language_changed"]
        log.info "Language changed, reseting proposal"
        # Invalidate all descriptions at once, they will be lazy-loaded again with new translations
        invalidate_description
        make_proposals(force_reset: force_reset, language_changed: true, callback: callback)
        return false
      end

      @triggers ||= {}
      @triggers[client] = description_map["trigger"] if description_map.key?("trigger")

      true
    end

    def clear_proposals_counter
      @proposals_run_counter = {}
    end

    # Updates internal counter that holds information how many times
    # has been each proposal called during the current make_proposals run
    def update_proposals_counter(proposals)
      @proposals_run_counter ||= {}

      proposals.each do |proposal|
        @proposals_run_counter[proposal] ||= 0
        @proposals_run_counter[proposal] += 1
      end
    end

    # Finds out whether we can call given proposals again during
    # the current make_proposals run
    def should_run_proposals_again?(proposals)
      update_proposals_counter(proposals)

      log.info "Proposal counters: #{@proposals_run_counter}"
      @proposals_run_counter.values.max < MAX_LOOPS_IN_PROPOSAL
    end

    def clear_triggers
      @triggers = {}
    end

    # Returns whether given trigger definition is correct
    # e.g., all mandatory parts are there
    #
    # @param [Hash] trigger definition
    # @rturn [Boolean] whether it is correct
    def valid_trigger?(trigger_def)
      trigger_def.key?("expect") &&
        trigger_def["expect"].is_a?(Hash) &&
        trigger_def["expect"].key?("class") &&
        trigger_def["expect"]["class"].is_a?(String) &&
        trigger_def["expect"].key?("method") &&
        trigger_def["expect"]["method"].is_a?(String) &&
        trigger_def.key?("value")
    end

    # Returns whether given client should be called again during 'this'
    # proposal run according to triggers
    #
    # @param [String] client name
    # @return [Boolean] whether it should be called
    def should_be_called_again?(client)
      @triggers ||= {}
      return false unless @triggers.key?(client)

      raise "Incorrect definition of 'trigger': #{@triggers[client].inspect} \n" \
        "both [Hash] 'expect', including keys [Symbol] 'class' and [Symbol] 'method', \n" \
        "and [Any] 'value' must be set" unless valid_trigger?(@triggers[client])

      expectation_class = @triggers[client]["expect"]["class"]
      expectation_method = @triggers[client]["expect"]["method"]
      expectation_value = @triggers[client]["value"]

      log.info "Calling #{expectation_class}.send(#{expectation_method.inspect})"

      begin
        value = Object.const_get(expectation_class).send(expectation_method)
      rescue StandardError, ScriptError => error
        raise "Checking the trigger expectations for #{client} have failed:\n#{error}"
      end

      if value == expectation_value
        log.info "Proposal client #{client}: returned value matches expectation #{value.inspect}"
        return false
      else
        log.info "Proposal client #{client}: returned value #{value.inspect} " \
          "does not match expected value #{expectation_value.inspect}"
        return true
      end
    end

    # Invalidates proposal description coming from a given client
    #
    # @param [String] client or nil for all descriptions
    def invalidate_description(client = nil)
      if client.nil?
        @descriptions = {}
      else
        @descriptions.delete(client)
      end
    end

    def properties
      @proposal_properties ||= Yast::ProductControl.getProposalProperties(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )
    end

    def make_proposal(client, force_reset: false, language_changed: false, callback: proc {})
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

      raise "Callback is not a block: #{callback.class}" unless callback.is_a? Proc
      callback.call(client, proposal)

      proposal
    end

    def global_help
      case @proposal_mode
      when "initial"
        if Yast::Mode.installation
          # Help text for installation proposal
          # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" \
              "Select <b>Install</b> to perform a new installation with the values displayed.\n" \
              "</p>\n"
            )
        else # so update
          # Help text for update proposal
          # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" \
              "Select <b>Update</b> to perform an update with the values displayed.\n" \
              "</p>\n"
          )
        end
      when "network"
        # Help text for network configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" \
            "Put the network settings into effect by pressing <b>Next</b>.\n" \
            "</p>\n"
        )
      when "service"
        # Help text for service configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" \
            "Put the service settings into effect by pressing <b>Next</b>.\n" \
            "</p>\n"
        )
      when "hardware"
        # Help text for hardware configuration proposal
        # General part ("You can change values...") is added as the next paragraph.
        _(
          "<p>\n" \
            "Put the hardware settings into effect by pressing <b>Next</b>.\n" \
            "</p>\n"
        )
      when "uml"
        # Proposal in uml module
        _("<P><B>UML Installation Proposal</B></P>") \
        # help text
        _(
          "<P>UML (User Mode Linux) installation allows you to start independent\nLinux virtual machines in the host system.</P>"
        )
      else
        if properties["help"] && !properties["help"].empty?
          # Proposal help from control file module
          Yast::Builtins.dgettext(
            Yast::ProductControl.getProposalTextDomain,
            properties["help"]
          )
        else
          # Generic help text for other proposals (not basic installation or
          # hardhware configuration.
          # General part ("You can change values...") is added as the next paragraph.
          _(
            "<p>\n" \
              "To use the settings as displayed, press <b>Next</b>.\n" \
              "</p>\n"
          )
        end
      end
    end

    def order_with_tabs
      @modules_order = properties["proposal_tabs"]
      @modules_order.map! { |m| m["proposal_modules"] }

      @modules_order.each do |module_tab|
        module_tab.map! do |mod|
          mod.include?("_proposal") ? mod : mod + "_proposal"
        end
      end

      @modules_order
    end

    def order_without_tabs
      @modules_order = Yast::ProductControl.getProposals(
        Yast::Stage.stage,
        Yast::Mode.mode,
        @proposal_mode
      )

      @modules_order.sort_by! { |m| m[1] || 50 } # second element is presentation order

      @modules_order.map!(&:first)

      @modules_order
    end

    def modules_help(current_tab)
      modules_order = presentation_order
      if tabs? && current_tab
        modules_order = modules_order[current_tab]

        modules_order.each_with_object("") do |client, text|
          description = description_for(client)
          text << description["help"] if description["help"]
        end
      else
        ""
      end
    end
  end
end

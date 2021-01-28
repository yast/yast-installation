#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "erb"
require "y2firewall/firewalld/api"
require "installation/security_settings"
require "installation/dialogs/security"
require "installation/proposal_client"

module Installation
  module Clients
    # Firewall and SSH installation proposal client
    class SecurityProposal < ::Installation::ProposalClient
      include Yast::I18n
      include Yast::Logger

      # [Installation::SecuritySettings] Stores the proposal settings
      attr_accessor :settings

      SERVICES_LINKS = [
        LINK_ENABLE_FIREWALL = "security--enable_firewall".freeze,
        LINK_DISABLE_FIREWALL = "security--disable_firewall".freeze,
        LINK_OPEN_SSH_PORT = "security--open_ssh".freeze,
        LINK_BLOCK_SSH_PORT = "security--close_ssh".freeze,
        LINK_ENABLE_SSHD = "security--enable_sshd".freeze,
        LINK_DISABLE_SSHD = "security--disable_sshd".freeze,
        LINK_OPEN_VNC = "security--open_vnc".freeze,
        LINK_CLOSE_VNC = "security--close_vnc".freeze,
        LINK_CPU_MITIGATIONS = "security--cpu_mitigations".freeze
      ].freeze

      LINK_DIALOG = "security".freeze

      # Constructor
      def initialize
        Yast.import "UI"
        Yast.import "HTML"
        textdomain "installation"

        @settings ||= ::Installation::SecuritySettings.instance
      end

      def description
        {
          # Proposal title
          "rich_text_title" => _("Security"),
          # Menu entry label
          "menu_title"      => _("&Security"),
          "id"              => LINK_DIALOG
        }
      end

      def make_proposal(_attrs)
        {
          "preformatted_proposal" => preformatted_proposal,
          "warning_level"         => :warning,
          "links"                 => SERVICES_LINKS,
          "warning"               => warning
        }
      end

      def preformatted_proposal
        Yast::HTML.List(proposals)
      end

      def warning
        return nil unless @settings.access_problem?

        # TRANSLATORS: proposal warning text preventing the user to block
        # the root login by error.
        _("The 'root' user uses only SSH key-based authentication. <br>" \
          "With the current settings the user might not be allowed to login.")
      end

      def ask_user(param)
        chosen_link = param["chosen_id"]
        result = :next
        log.info "User clicked #{chosen_link}"

        if SERVICES_LINKS.include?(chosen_link)
          call_proposal_action_for(chosen_link)
        elsif chosen_link == LINK_DIALOG
          result = ::Installation::Dialogs::Security.new(@settings).run
        else
          raise "INTERNAL ERROR: unknown action '#{chosen_link}' for proposal client"
        end

        { "workflow_sequence" => result }
      end

      def write
        { "success" => true }
      end

    private

      # Obtain and call the corresponding method for the clicked link.
      def call_proposal_action_for(link)
        action = link.gsub("security--", "")
        if action == "cpu_mitigations"
          bootloader_dialog
        else
          @settings.public_send("#{action}!")
        end
      end

      # Array with the available proposal descriptions.
      #
      # @return [Array<String>] services and ports descriptions
      def proposals
        # Filter proposals with content
        [cpu_mitigations_proposal, firewall_proposal, sshd_proposal,
         ssh_port_proposal, vnc_fw_proposal,
         polkit_default_priv_proposal].compact
      end

      # Returns the cpu mitigation part of the bootloader proposal description
      # Returns nil if this part should be skipped
      # @return [String] proposal html text
      def cpu_mitigations_proposal
        require "bootloader/bootloader_factory"
        bl = ::Bootloader::BootloaderFactory.current
        return nil if bl.name == "none"

        mitigations = bl.cpu_mitigations

        res = _("CPU Mitigations: ") + "<a href=\"#{LINK_CPU_MITIGATIONS}\">" +
          ERB::Util.html_escape(mitigations.to_human_string) + "</a>"
        log.info "mitigations output #{res.inspect}"
        res
      end

      def bootloader_dialog
        require "bootloader/config_dialog"
        Yast.import "Bootloader"

        begin
          # do it in own dialog window
          Yast::Wizard.CreateDialog
          dialog = ::Bootloader::ConfigDialog.new(initial_tab: :kernel)
          settings = Yast::Bootloader.Export
          result = dialog.run
          if result != :next
            Yast::Bootloader.Import(settings)
          else
            Yast::Bootloader.proposed_cfg_changed = true
          end
        ensure
          Yast::Wizard.CloseDialog
        end
      end

      # Returns the VNC-port part of the firewall proposal description
      # Returns nil if this part should be skipped
      # @return [String] proposal html text
      def vnc_fw_proposal
        # It only makes sense to show the blocked ports if firewall is
        # enabled (bnc#886554)
        return nil unless @settings.enable_firewall
        # Show VNC port only if installing over VNC
        return nil unless Linuxrc.vnc

        if @settings.open_vnc
          _("VNC ports will be open (<a href=\"%s\">block</a>)") % LINK_CLOSE_VNC
        else
          _("VNC ports will be blocked (<a href=\"%s\">open</a>)") % LINK_OPEN_VNC
        end
      end

      # Returns the SSH-port part of the firewall proposal description
      # Returns nil if this part should be skipped
      # @return [String] proposal html text
      def ssh_port_proposal
        return nil unless @settings.enable_firewall

        if @settings.open_ssh
          _("SSH port will be open (<a href=\"%s\">block</a>)") % LINK_BLOCK_SSH_PORT
        else
          _("SSH port will be blocked (<a href=\"%s\">open</a>)") % LINK_OPEN_SSH_PORT
        end
      end

      # Returns the Firewalld service part of the firewall proposal description
      # @return [String] proposal html text
      def firewall_proposal
        if @settings.enable_firewall
          _(
            "Firewall will be enabled (<a href=\"%s\">disable</a>)"
          ) % LINK_DISABLE_FIREWALL
        else
          _(
            "Firewall will be disabled (<a href=\"%s\">enable</a>)"
          ) % LINK_ENABLE_FIREWALL
        end
      end

      # Returns the SSH service part of the firewall proposal description
      # @return [String] proposal html text
      def sshd_proposal
        if @settings.enable_sshd
          _(
            "SSH service will be enabled (<a href=\"%s\">disable</a>)"
          ) % LINK_DISABLE_SSHD
        else
          _(
            "SSH service will be disabled (<a href=\"%s\">enable</a>)"
          ) % LINK_ENABLE_SSHD
        end
      end

      def polkit_default_priv_proposal
        value = @settings.polkit_default_proviledges || "default"
        human_value = @settings.human_polkit_priviledges[value]

        format(_("PolicyKit Default Priviledges: %s"), human_value)
      end
    end
  end
end

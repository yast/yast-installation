#!/usr/bin/env rspec
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

require_relative "../../test_helper.rb"
require "installation/clients/security_proposal"
require "bootloader/config_dialog"

describe Installation::Clients::SecurityProposal do
  subject(:client) { described_class.new }
  let(:proposal_settings) { Installation::SecuritySettings.create_instance }

  describe "#initialize" do
    it "instantiates a new proposal settings" do
      expect(Installation::SecuritySettings).to receive(:instance)

      described_class.new
    end
  end

  describe "#description" do
    it "returns a hash with 'id', 'rich_text_title' and 'menu_title'" do
      description = client.description
      expect(description).to be_a Hash
      expect(description).to include("id", "menu_title", "rich_text_title")
    end
  end

  describe "#ask_user" do
    let(:param) { { "chosen_id" => action } }
    let(:dialog) { instance_double(Installation::Dialogs::Security) }

    before do
      allow(Installation::Dialogs::Security).to receive(:new).and_return(dialog)
    end

    context "when 'chosen_id' is equal to the description id" do
      let(:action) { client.description["id"] }

      it "runs the proposal dialog" do
        expect(dialog).to receive(:run)

        client.ask_user(param)
      end

      it "returns a hash with the proposal dialog result for 'workflow_sequence' key" do
        allow(dialog).to receive(:run).and_return(:result)

        result = client.ask_user(param)
        expect(result).to be_a(Hash)
        expect(result["workflow_sequence"]).to eq :result
      end
    end

    context "when 'chosen_id' corresponds to some of the services links" do
      let(:action) { described_class::SERVICES_LINKS.first }

      it "calls the corresponding action for the chosen link" do
        expect(client).to receive("call_proposal_action_for").with(action)

        client.ask_user(param)
      end

      it "returns a hash with :next for 'workflow_sequence' key" do
        result = client.ask_user(param)
        expect(result).to be_a(Hash)
        expect(result["workflow_sequence"]).to eq :next
      end
    end

    context "when 'chosen_id' corresponds to cpu_mitigations" do
      let(:action) { "security--cpu_mitigations" }

      it "opens bootloader dialog" do
        allow(::Bootloader::ConfigDialog).to receive(:new).with(initial_tab: :kernel)
          .and_return(double(run: :next))
        allow(Yast::Wizard).to receive(:CreateDialog)
        allow(Yast::Wizard).to receive(:CloseDialog)
        expect(client).to receive("call_proposal_action_for").with(action)

        client.ask_user(param)
      end
    end

  end

  describe "#make_proposal" do
    let(:firewall_enabled) { false }

    before do
      allow(proposal_settings).to receive("enable_firewall").and_return(firewall_enabled)

      allow(proposal_settings.selinux_config).to receive(:configurable?)
        .and_return(false)
    end

    it "returns a hash with 'preformatted_proposal', 'links', 'warning_level' and 'warning'" do
      allow(Yast::HTML).to receive("List").and_return("<ul><li>Proposal link</li></ul>")

      proposal = client.make_proposal({})
      expect(proposal).to be_a Hash
      expect(proposal).to include("preformatted_proposal", "links", "warning_level")
    end

    context "when firewalld is disabled" do
      it "returns the 'preformatted_proposal' without links to open/close ports" do
        proposal = client.make_proposal({})

        expect(proposal["preformatted_proposal"]).to_not include("port")
      end
    end

    context "when firewalld is enabled" do
      let(:firewall_enabled) { true }

      it "returns the 'preformatted_proposal' with links to open/close ports" do
        proposal = client.make_proposal({})

        expect(proposal["preformatted_proposal"]).to include("port")
      end
    end

    context "when selinux is configurable" do
      it "contains in proposal selinux configuration" do
        allow(proposal_settings.selinux_config).to receive(:configurable?)
          .and_return(true)
        allow(Yast::Bootloader).to receive(:kernel_param).and_return(:missing)

        proposal = client.make_proposal({})

        expect(proposal["preformatted_proposal"]).to include("SELinux Default Mode")
      end
    end

    context "when the user uses only SSH key based authentication" do
      let(:ssh_enabled) { true }
      let(:ssh_open) { true }

      before do
        allow(proposal_settings).to receive(:only_public_key_auth).and_return(true)
        proposal_settings.enable_sshd = ssh_enabled
        proposal_settings.open_ssh = ssh_open
      end

      context "and the SSH service is enabled" do
        context "and the SSH port is open" do
          it "the 'proposal' does not contain a warning message" do
            proposal = client.make_proposal({})
            expect(proposal["warning"]).to be_nil
          end
        end
        context "and the SSH port is close" do
          let(:ssh_open) { false }

          it "returns the proposal warning about the situation" do
            proposal = client.make_proposal({})
            expect(proposal["warning"]).to include("might not be allowed")
          end
        end
      end

      context "and the SSH is disabled" do
        let(:ssh_enabled) { false }

        it "returns the proposal warning about the situation" do
          proposal = client.make_proposal({})
          expect(proposal["warning"]).to include("might not be allowed")
        end
      end
    end

    context "when showing the PolicyKit Default privileges selected" do
      let(:selected) { "" }

      before do
        allow(proposal_settings).to receive(:polkit_default_privileges).and_return(selected)
      end

      context "and it is not set" do
        let(:selected) { nil }

        it "shows it as 'Default'" do
          proposal = client.make_proposal({})
          expect(proposal["preformatted_proposal"]).to include("Privileges: Default")
        end
      end

      context "and it is empty" do
        let(:selected) { nil }

        it "shows it as 'Default'" do
          proposal = client.make_proposal({})
          expect(proposal["preformatted_proposal"]).to include("Privileges: Default")
        end
      end
      context "and it is restrictive" do
        let(:selected) { "restrictive" }

        it "shows it as 'Restrictive'" do
          proposal = client.make_proposal({})
          expect(proposal["preformatted_proposal"]).to include("Privileges: Restrictive")
        end
      end
    end
  end
end

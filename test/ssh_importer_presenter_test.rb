#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/ssh_importer_presenter"
require "installation/ssh_importer"

describe ::Installation::SshImporterPresenter do
  Yast.import "Mode"

  let(:importer) { ::Installation::SshImporter.instance }
  let(:presenter) { described_class.new(importer) }

  describe "#summary" do
    let(:mode) { "installation" }
    let(:device) { "dev" }
    let(:copy_config) { false }

    before do
      textdomain "installation"

      importer.configurations.clear
      importer.reset
      importer.add_config(FIXTURES_DIR.join(config), "dev")
      importer.device = device
      importer.copy_config = copy_config
      allow(Yast::Mode).to receive(:mode).and_return(mode)
    end

    context "when no previous configurations were found" do
      let(:config) { "root3" }
      let(:device) { nil }

      context "and mode is installation" do
        let(:mode) { "installation" }
        let(:message) { _("No previous Linux installation found") }

        it "returns 'No previous Linux...' message" do
          expect(presenter.summary).to include(message)
        end
      end

      context "and mode is autoinstallation" do
        let(:mode) { "autoinstallation" }
        let(:message) { _("No previous Linux installation found") }

        it "returns 'No previous Linux...' message" do
          expect(presenter.summary).to include(message)
        end
      end

      context "and mode is not installation or autoinstallation" do
        let(:mode) { "normal" }
        let(:message) { _("No existing SSH host keys will be copied") }

        it "returns 'No previous Linux...' message" do
          expect(presenter.summary).to include(message)
        end
      end
    end

    context "when device is set and copy config is enabled" do
      let(:config) { "root1" }
      let(:copy_config) { true }
      let(:message) do
        _("SSH host keys and configuration will be copied from %s") %
          "Operating system 1"
      end

      it "returns 'SSH host keys and configuration...'" do
        expect(presenter.summary).to include(message)
      end
    end

    context "when device is set and copy config is disabled" do
      let(:config) { "root1" }
      let(:message) do
        _("SSH host keys will be copied from %s") %
          "Operating system 1"
      end

      it "returns 'SSH host keys will be copied...'" do
        expect(presenter.summary).to include(message)
      end
    end
  end
end

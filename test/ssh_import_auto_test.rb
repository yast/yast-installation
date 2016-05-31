#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/ssh_import_auto"

describe ::Installation::SSHImportAutoClient do
  let(:importer) { ::Installation::SshImporter.instance }
  let(:mode) { "autoinstallation" }
  let(:args) { [] }

  before do
    allow(Yast::WFM).to receive(:Args).and_return([func, args])
    allow(Yast::Mode).to receive(:mode).and_return(mode)
  end

  describe "#run" do
    before do
      importer.configurations.clear
      importer.reset
    end

    context "Export" do
      let(:func) { "Export" }

      it "returns a hash with default configuration" do
        expect(subject.run).to eq("config" => false, "import" => true)
      end
    end

    context "Summary" do
      let(:func) { "Summary" }
      let(:device) { "dev" }
      let(:copy_config) { false }

      before do
        importer.add_config(FIXTURES_DIR.join(config), "dev")
        importer.device = device
        importer.copy_config = copy_config
      end

      context "when no previous configurations were found" do
        let(:config) { "root3" }
        let(:message) { _("No previous Linux installation found") }
        let(:device) { nil }

        it "returns 'No previous Linux...' message" do
          expect(subject.run).to eq("<UL><LI>#{message}</LI></UL>")
        end
      end

      context "when no device was selected" do
        let(:config) { "root1" }
        let(:device) { nil }
        let(:message) { _("No existing SSH host keys will be copied") }

        it "returns 'No existing SSH...'" do
          expect(subject.run).to eq("<UL><LI>#{message}</LI></UL>")
        end
      end

      context "when device is set and copy config is enabled" do
        let(:config) { "root1" }
        let(:copy_config) { true }
        let(:message) do
          _("SSH host keys and configuration will be copied from %s") %
            "Operating system 1"
        end

        it "returns 'No existing SSH...'" do
          expect(subject.run).to eq("<UL><LI>#{message}</LI></UL>")
        end
      end

      context "when device is set and copy config is disabled" do
        let(:config) { "root1" }
        let(:copy_config) { false }
        let(:message) do
          _("SSH host keys will be copied from %s") %
            "Operating system 1"
        end

        it "returns 'No existing SSH...'" do
          expect(subject.run).to eq("<UL><LI>#{message}</LI></UL>")
        end
      end
    end

    context "Import" do
      let(:func) { "Import" }

      before do
        importer.add_config(FIXTURES_DIR.join("root1"), "dev")
      end

      context "when importing is disabled" do
        let(:args) { { "import" => false } }

        it "unset the device" do
          subject.run
          expect(importer.device).to be_nil
        end
      end

      context "when no device is set" do
        let(:args) { { "import" => true } }

        it "sets default device to be used" do
          subject.run
          expect(importer.device).to eq("dev")
        end
      end

      context "when given device exist" do
        let(:args) { { "import" => true, "device" => "other" } }

        it "sets given device to be used" do
          importer.add_config(FIXTURES_DIR.join("root1"), "other")
          subject.run
          expect(importer.device).to eq("other")
        end
      end

      context "when given device does not exist" do
        let(:args) { { "import" => true, "device" => "missing" } }

        it "sets default device to be used" do
          subject.run
          expect(importer.device).to eq("dev")
        end
      end

      context "when copying configuration is disabled" do
        let(:args) { { "import" => true, "config" => false } }

        it "disable copy_config to false" do
          subject.run
          expect(importer.copy_config).to eq(false)
        end
      end

      context "when copying configuration is enabled" do
        let(:args) { { "import" => true, "config" => true } }

        it "disable copy_config to true" do
          subject.run
          expect(importer.copy_config).to eq(true)
        end
      end
    end

    context "Write" do
      let(:func) { "Write" }

      before do
        importer.add_config(FIXTURES_DIR.join("root1"), "dev")
        allow(::Installation).to receive(:destdir).and_return("/")
      end

      it "writes the keys/configuration to the installation directory" do
        configuration = importer.configurations["dev"]
        expect(configuration).to receive(:write_files).with("/",
          write_keys: true, write_config_files: importer.copy_config)
        subject.run
      end
    end

    context "Read" do
      let(:func) { "Read" }

      it "returns true" do
        expect(subject.run).to eq(true)
      end
    end

    context "Reset" do
      let(:func) { "Reset" }

      it "resets the importer" do
        expect(importer).to receive(:reset)
        subject.run
      end
    end

    context "GetModified" do
      let(:func) { "GetModified" }

      before { described_class.changed = false }

      context "when client was not changed" do
        it "returns false" do
          expect(subject.run).to eq(false)
        end
      end

      context "when client was changed" do
        before { subject.modified }

        it "returns true" do
          expect(subject.run).to eq(true)
        end
      end
    end

    context "SetModified" do
      let(:func) { "SetModified" }

      before { described_class.changed = false }

      it "sets the client as 'modified'" do
        expect { subject.run }.to change { subject.modified? }
          .from(false).to(true)
      end
    end
  end
end

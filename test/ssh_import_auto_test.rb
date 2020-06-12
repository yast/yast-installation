#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/ssh_import_auto"

describe ::Installation::SSHImportAutoClient do
  textdomain "installation"

  let(:importer) { ::Installation::SshImporter.instance }
  let(:mode) { "autoinstallation" }
  let(:args) { [] }

  before do
    textdomain "installation"
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

      context "config mode" do
        let(:mode) { "autoinst_config" }

        it "returns a hash with configuration" do
          importer.add_config(fixtures_dir("root1"), "dev")
          expect(subject.run).to eq(
            "copy_config" => false,
            "device" => "dev",
            "import" => true
          )
        end
      end

      context "other modes" do
        it "returns an empty hash" do
          expect(subject.run).to eq({})
        end
      end
    end

    context "Summary" do
      let(:func) { "Summary" }
      let(:presenter) { double("presenter", summary: "Summary") }

      before do
        allow(::Installation::SshImporterPresenter).to receive(:new).and_return(presenter)
      end

      it "returns SSH importer summary" do
        expect(subject.run).to eq(presenter.summary)
      end
    end

    context "Import" do
      let(:func) { "Import" }

      before do
        importer.add_config(fixtures_dir("root1"), "dev")
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
          importer.add_config(fixtures_dir("root1"), "other")
          subject.run
          expect(importer.device).to eq("other")
        end
      end

      context "when given device does not exist" do
        let(:args) { { "import" => true, "device" => "missing" } }

        it "sets default device to be used and warns the user" do
          expect(Yast::Report).to receive(:Warning)
            .with(_("Device missing not found. Using data from dev."))
          subject.run
          expect(importer.device).to eq("dev")
        end
      end

      context "when copying configuration is disabled" do
        let(:args) { { "import" => true, "copy_config" => false } }

        it "sets copy_config to false" do
          subject.run
          expect(importer.copy_config).to eq(false)
        end
      end

      context "when copying configuration is enabled" do
        let(:args) { { "import" => true, "copy_config" => true } }

        it "sets copy_config to true" do
          subject.run
          expect(importer.copy_config).to eq(true)
        end
      end
    end

    context "Write" do
      let(:func) { "Write" }

      before do
        importer.add_config(fixtures_dir("root1"), "dev")
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

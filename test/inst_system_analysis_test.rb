#!/usr/bin/env rspec

require_relative "./test_helper"
require "installation/clients/inst_system_analysis"

Yast.import "Product"
Yast.import "InstData"
Yast.import "StorageDevices"
Yast.import "StorageControllers"

describe Yast::InstSystemAnalysisClient do
  subject(:client) { Yast::InstSystemAnalysisClient.new }

  describe "#download_and_show_release_notes" do
    let(:product) { "openSUSE" }
    let(:notes) { "some release notes" }

    before do
      allow(Yast::WFM).to receive(:CallFunction).with("inst_download_release_notes")
        .and_return(:auto)
      allow(Yast::Product).to receive(:short_name).and_return(product)
      allow(Yast::InstData).to receive(:release_notes).and_return(release_notes)
      stub_const("Yast::Packages", double(GetBaseSourceID: 0))
    end

    context "when release notes were downloaded" do
      let(:release_notes) { { product => notes } }

      it "does not enable the button nor load release notes again" do
        expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
        expect(Yast::UI).to_not receive(:SetReleaseNotes)
        client.download_and_show_release_notes
      end
    end

    context "when release notes were not downloaded" do
      let(:release_notes) { {} }

      context "but can be loaded from media" do
        before do
          allow(client).to receive(:load_release_notes).and_return(true)
          client.instance_variable_set(:@media_text, notes)
        end

        it "enables the button and load the release notes" do
          expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
          expect(Yast::UI).to receive(:SetReleaseNotes).with(product => notes)
          client.download_and_show_release_notes
          expect(Yast::InstData.release_notes).to eq(product => notes)
        end
      end

      context "and could not be loaded from media" do
        before do
          allow(client).to receive(:load_release_notes).and_return(false)
        end

        it "does not enable the button nor load release notes" do
          expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
          expect(Yast::UI).to_not receive(:SetReleaseNotes)
          client.download_and_show_release_notes
        end
      end
    end
  end

  describe "#ActionHDDProbe" do
    let(:controllers) { 1 }
    let(:auto) { false }
    let(:s390) { false }

    before do
      allow(Yast::StorageDevices).to receive(:Probe).and_return(target_map)
      allow(Yast::StorageControllers).to receive(:Probe).and_return(controllers)
      allow(Yast::Mode).to receive(:auto).and_return(auto)
      allow(Yast::Arch).to receive(:s390).and_return(s390)
      client.ActionHHDControllers
    end

    context "when disks were found" do
      let(:target_map) { [{ "bus" => "ide" }] }

      it "returns true" do
        expect(client.ActionHDDProbe).to eq(true)
      end
    end

    context "when no disk were found" do
      let(:target_map) { [] }

      it "returns false" do
        expect(client.ActionHDDProbe).to eq(false)
      end

      context "but disk controllers were found" do
        let(:controllers) { 1 }

        context "during autoinstallation" do
          let(:auto) { true }

          it "reports a warning" do
            expect(Yast::Report).to receive(:Warning)
            client.ActionHDDProbe
          end
        end

        context "during autoinstallation" do
          let(:auto) { false }

          it "reports an error" do
            expect(Yast::Report).to receive(:Error)
            client.ActionHDDProbe
          end
        end
      end

      context "and disks controllers were not found" do
        let(:controllers) { 0 }

        context "during autoinstallation" do
          let(:auto) { true }

          it "reports a warning" do
            expect(Yast::Report).to receive(:Warning)
            client.ActionHDDProbe
          end
        end

        context "during autoinstallation" do
          let(:auto) { false }

          it "reports an error" do
            expect(Yast::Report).to receive(:Error)
            client.ActionHDDProbe
          end
        end

        context "but is a s390 system" do
          context "during autoinstallation" do
            let(:auto) { true }

            it "reports a warning" do
              expect(Yast::Report).to receive(:Warning)
              client.ActionHDDProbe
            end
          end

          context "during autoinstallation" do
            let(:auto) { false }

            it "reports an error" do
              expect(Yast::Report).to receive(:Error)
              client.ActionHDDProbe
            end
          end
        end
      end
    end
  end
end

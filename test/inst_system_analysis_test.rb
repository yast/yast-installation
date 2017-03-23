#!/usr/bin/env rspec

require_relative "./test_helper"
require "installation/clients/inst_system_analysis"

Yast.import "Product"
Yast.import "InstData"

describe Yast::InstSystemAnalysisClient do
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
        subject.download_and_show_release_notes
      end
    end

    context "when release notes were not downloaded" do
      let(:release_notes) { {} }

      context "but can be loaded from media" do
        before do
          allow(subject).to receive(:load_release_notes).and_return(true)
          subject.instance_variable_set(:@media_text, notes)
        end

        it "enables the button and load the release notes" do
          expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
          expect(Yast::UI).to receive(:SetReleaseNotes).with(product => notes)
          subject.download_and_show_release_notes
          expect(Yast::InstData.release_notes).to eq(product => notes)
        end
      end

      context "and could not be loaded from media" do
        before do
          allow(subject).to receive(:load_release_notes).and_return(false)
        end

        it "does not enable the button nor load release notes" do
          expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
          expect(Yast::UI).to_not receive(:SetReleaseNotes)
          subject.download_and_show_release_notes
        end
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/clients/inst_download_release_notes"
require "y2packager/release_notes"

describe Yast::InstDownloadReleaseNotesClient do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:sles_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SLES RN") }
    let(:sdk_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SDK RN") }

    let(:sles) do
      instance_double(Y2Packager::Product, short_name: "SLES", release_notes: sles_relnotes)
    end

    let(:sdk) do
      instance_double(Y2Packager::Product, short_name: "SDK", release_notes: sdk_relnotes)
    end

    let(:textmode) { true }
    let(:inst_data) { double("inst_data") }
    let(:initial) { true }

    before do
      allow(Yast::UI).to receive(:TextMode).and_return(textmode)
      allow(Y2Packager::Product).to receive(:with_status).with(:selected)
        .and_return([sles, sdk])
      allow(Yast::Stage).to receive(:initial).and_return(initial)
    end

    it "sets release notes content" do
      expect(Yast::UI).to receive(:SetReleaseNotes).with(
        "SLES" => "SLES RN",
        "SDK"  => "SDK RN"
      )
      subject.download_release_notes
    end

    it "enables the release notes button" do
      expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
      subject.download_release_notes
    end

    context "when no release notes are found" do
      before do
        allow(sles).to receive(:release_notes).and_return(nil)
        allow(sdk).to receive(:release_notes).and_return(nil)
      end

      it "does not enable the release notes button" do
        expect(Yast::UI).to receive(:SetReleaseNotes).with({})
        expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
        subject.download_release_notes
      end
    end

    context "when running in text mode" do
      let(:textmode) { true }

      it "asks for :txt version" do
        expect(sles).to receive(:release_notes).with(:txt)
        subject.download_release_notes
      end
    end

    context "when running in graphical mode" do
      let(:textmode) { false }

      it "asks for :rtf version" do
        expect(sles).to receive(:release_notes).with(:rtf)
        subject.download_release_notes
      end
    end

    it "sets InstData.release_notes" do
      subject.download_release_notes
      expect(Yast::InstData.release_notes).to eq(
        "SLES" => "SLES RN", "SDK" => "SDK RN"
      )
    end

    context "when not running on initial stage" do
      let(:initial) { false }

      it "gets release notes from 'selected' or 'installed' products" do
        expect(Y2Packager::Product).to receive(:with_status).with(:selected, :installed)
          .and_return([sles])
        expect(sles).to receive(:release_notes)
        expect(sdk).to_not receive(:release_notes)
        subject.download_release_notes
      end
    end

    context "when a product is selected" do
      it "gets release notes from the selected package" do
        expect(Y2Packager::Product).to receive(:with_status).with(:selected)
          .and_return([sles])
        expect(sles).to receive(:release_notes)
        expect(sdk).to_not receive(:release_notes)
        subject.download_release_notes
      end
    end

    context "when no product is selected" do
      it "gets release notes from the available packages" do
        expect(Y2Packager::Product).to receive(:with_status).with(:selected)
          .and_return([])
        expect(Y2Packager::Product).to receive(:with_status).with(:available)
          .and_return([sles])
        expect(sles).to receive(:release_notes)
        expect(sdk).to_not receive(:release_notes)
        subject.download_release_notes
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/clients/inst_download_release_notes"

describe Yast::InstDownloadReleaseNotesClient do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:sles) do
      instance_double(Y2Packager::Product, short_name: "SLES", release_notes: "SLES RN")
    end

    let(:sdk) do
      instance_double(Y2Packager::Product, short_name: "SDK", release_notes: "SDK RN")
    end

    before do
      allow(Yast::UI).to receive(:TextMode).and_return(true)
      allow(Y2Packager::Product).to receive(:with_status).with(:available)
        .and_return([sles, sdk])
      allow(Yast::Stage).to receive(:initial).and_return(true)
      Yast::InstData.main
    end

    it "sets InstData.release_notes" do
      subject.download_release_notes
      expect(Yast::InstData.release_notes).to eq(
        "SLES" => "SLES RN",
        "SDK"  => "SDK RN"
      )
      expect(Yast::InstData.downloaded_release_notes).to eq(["SLES", "SDK"])
    end

    it "enables the release notes button" do
      expect(Yast::UI).to receive(:SetReleaseNotes)
      expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
      subject.download_release_notes
    end

    context "when no release notes are found" do
      before do
        allow(sles).to receive(:release_notes).and_return(nil)
        allow(sdk).to receive(:release_notes).and_return(nil)
      end

      it "does not enable the release notes button" do
        expect(Yast::UI).to_not receive(:SetReleaseNotes)
        expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
        subject.download_release_notes
      end
    end
  end
end

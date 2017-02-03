#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/clients/inst_download_release_notes"

Yast.import "InstData"
Yast.import "Pkg"
Yast.import "Language"

describe Yast::InstDownloadReleaseNotesClient do
  CURL_NOT_FOUND_CODE = 22
  CURL_SUCCESS_CODE = 0
  CURL_HARD_ERROR = 7

  subject(:client) { described_class.new }

  let(:relnotes_url) do
    "http://doc.opensuse.org/release-notes/x86_64/openSUSE/Leap42.1/release-notes-openSUSE.rpm"
  end

  let(:product) do
    {
      "arch" => "x86_64", "description" => "openSUSE Leap", "category" => "base",
      "status" => :selected, "short_name" => "openSUSE",
      "relnotes_url" => relnotes_url
    }
  end

  describe "#main" do
    let(:proxy) { double("proxy", "Read" => nil, "enabled" => false) }
    let(:curl_code) { CURL_SUCCESS_CODE }
    let(:language) { "en_US" }

    before do
      stub_const("Yast::Proxy", proxy)
      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return([product])

      allow(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash"), /curl.*directory.yast/)
        .and_return(CURL_NOT_FOUND_CODE)

      allow(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash"), /curl.*relnotes/)
        .and_return(curl_code)

      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.tmpdir"))
      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.string"), /relnotes/)
        .and_return("RELNOTES CONTENT")

      allow(Yast::Language).to receive(:language).and_return(language)

      Yast::InstData.main # reset installation data
    end

    it "returns :auto" do
      expect(client.main).to eq(:auto)
    end

    context "when release notes are downloaded correctly" do
      let(:curl_code) { 0 }

      it "saves release notes in InstData" do
        client.main
        expect(Yast::InstData.release_notes["openSUSE"]).to eq("RELNOTES CONTENT")
      end
    end

    context "when release notes cannot be downloaded due to a hard error" do
      let(:curl_code) { CURL_HARD_ERROR }

      it "does not retry" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*relnotes/)
          .once.and_return(curl_code)
        client.main
      end

      it "does not save release notes" do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*relnotes/)
          .and_return(curl_code)
        client.main
        expect(Yast::InstData.release_notes["openSUSE"]).to be_nil
      end
    end

    context "when release notes are not found for the default language" do
      let(:language) { "es_ES" }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language}/)
          .and_return(CURL_NOT_FOUND_CODE) # not found
      end

      it "falls back to the generic language (es_ES -> es)" do
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language[0..1]}.rtf/)
          .and_return(CURL_NOT_FOUND_CODE)
        client.main
      end

      context "and are not found for the generic language" do
        before do
          allow(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language[0..1]}.rtf/)
            .and_return(CURL_NOT_FOUND_CODE) # not found
        end

        it "falls back to 'en'" do
          expect(Yast::SCR).to receive(:Execute).once
            .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.en.rtf/)
            .and_return(CURL_NOT_FOUND_CODE)
          client.main
        end
      end

      context "and default language is 'en_*'" do
        let(:language) { "en_US" }

        # bsc#1015794
        it "tries only 1 time with 'en'" do
          expect(Yast::SCR).to receive(:Execute).once
            .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.en.rtf/)
            .and_return(CURL_NOT_FOUND_CODE)
          client.main
        end
      end
    end

    context "when release notes index file is found" do
      let(:language) { "es_ES" }

      it "Reads the index and falls back to es" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*directory.yast/)
          .and_return(CURL_SUCCESS_CODE)
        expect(File).to receive(:read)
          .with(/directory.yast/)
          .and_return("foo\nRELEASE-NOTES.es.rtf\nbar")
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language[0..1]}.rtf/)
          .and_return(CURL_SUCCESS_CODE)
        client.main
      end

      it "Tries to read the index file, which is empty, falls back to es" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*directory.yast/)
          .and_return(CURL_SUCCESS_CODE)
        expect(File).to receive(:read)
          .with(/directory.yast/)
          .and_return("")
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language}.rtf/)
          .and_return(CURL_NOT_FOUND_CODE)
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.#{language[0..1]}.rtf/)
          .and_return(CURL_SUCCESS_CODE)
        client.main
      end
    end

    context "when called twice" do
      let(:language) { "en" }
      let(:curl_code) { 22 }

      it "does not try to download again already failed release notes" do
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.en.rtf/)
          .and_return(CURL_NOT_FOUND_CODE)
        client.main
        client.main # call it a second time
      end

      it "does not download again already downloaded release notes" do
        expect(Yast::SCR).to receive(:Execute).once
          .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES.en.rtf/)
          .and_return(CURL_SUCCESS_CODE)
        client.main
        client.main # call it a second time
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/inst_download_release_notes"

describe Yast::InstDownloadReleaseNotesClient do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:sles_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SLES RN") }
    let(:sdk_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SDK RN") }
    let(:language) { double("Yast::Language", language: "en_US") }

    let(:sles) do
      instance_double(Y2Packager::Product, short_name: "SLES", release_notes: sles_relnotes)
    end

    let(:sdk) do
      instance_double(Y2Packager::Product, short_name: "SDK", release_notes: sdk_relnotes)
    end

    let(:textmode) { true }
    let(:packages_init_called) { true }

    before do
      allow(Yast::UI).to receive(:TextMode).and_return(textmode)
      allow(Y2Packager::Product).to receive(:with_status).with(:selected)
        .and_return([sles, sdk])
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Packages).to receive(:init_called).and_return(packages_init_called)
      stub_const("Yast::Language", language)

      Yast::InstData.main
    end

    it "sets InstData.release_notes" do
      client.main
      expect(Yast::InstData.release_notes).to eq("SLES" => "SLES RN", "SDK" => "SDK RN")
    end

    it "sets release notes content" do
      expect(Yast::UI).to receive(:SetReleaseNotes).with(
        "SLES" => "SLES RN",
        "SDK"  => "SDK RN"
      )
      client.main
    end

    it "enables the release notes button" do
      expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
      client.main
    end

    context "when no release notes are found" do
      before do
        allow(sles).to receive(:release_notes).and_return(nil)
        allow(sdk).to receive(:release_notes).and_return(nil)
      end

      it "does not enable the release notes button" do
        expect(Yast::UI).to receive(:SetReleaseNotes).with({})
        expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
        client.main
      end
    end

    context "when running in text mode" do
      let(:textmode) { true }

      it "asks for :txt version" do
        expect(sles).to receive(:release_notes).with(language.language, :txt)
        client.main
      end
    end

    context "when running in graphical mode" do
      let(:textmode) { false }

      it "asks for :rtf version" do
        expect(sles).to receive(:release_notes).with(language.language, :rtf)
        client.main
      end
    end

    context "when running in auto mode" do
      before do
        allow(Yast::Mode).to receive(:auto).and_return(true)
      end

      it "returns :auto" do
        expect(subject.main).to eq(:auto)
      end
    end

    context "going back" do
      before do
        allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)
      end

      it "returns :auto" do
        expect(subject.main).to eq(:back)
      end
    end

    context "when Packages module has not be initialized" do
      let(:packages_init_called) { false }

      it "returns :auto" do
        expect(subject.main).to eq(:auto)
      end
    end

    describe "products selection" do
      before do
        allow(Y2Packager::Product).to receive(:with_status) do |*args|
          args.each_with_object([]) do |status, all|
            all.concat(products[status])
          end
        end
      end

      context "when some package is selected" do
        let(:products) do
          { selected: [sles], available: [sdk] }
        end

        it "shows release notes for 'selected' packages" do
          expect(sles).to receive(:release_notes)
          expect(sdk).to_not receive(:release_notes)
          client.main
        end
      end

      context "when no package is selected" do
        let(:products) do
          { selected: [], available: [sdk], installed: [sles] }
        end

        it "shows release notes for 'available' packages" do
          expect(sles).to_not receive(:release_notes)
          expect(sdk).to receive(:release_notes)
          client.main
        end
      end

      context "when not running on initial stage" do
        let(:other_product) { double("Y2Packager::Product") }

        let(:products) do
          { available: [other_product], selected: [sdk], installed: [sles] }
        end

        before do
          allow(Yast::Stage).to receive(:initial).and_return(false)
        end

        it "shows release notes for 'selected' and 'available' packages" do
          expect(sles).to receive(:release_notes)
          expect(sdk).to receive(:release_notes)
          expect(other_product).to_not receive(:release_notes)
          client.main
        end
      end
    end
  end
end

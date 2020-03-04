#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/inst_download_release_notes"

describe Yast::InstDownloadReleaseNotesClient do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:sles_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SLES RN") }
    let(:sdk_relnotes) { instance_double(Y2Packager::ReleaseNotes, content: "SDK RN") }
    let(:products) { [sles, sdk] }
    let(:language) { double("Yast::Language", language: "en_US") }

    let(:sles) do
      instance_double(Y2Packager::Product, short_name: "SLES", release_notes: sles_relnotes)
    end

    let(:sdk) do
      instance_double(Y2Packager::Product, short_name: "SDK", release_notes: sdk_relnotes)
    end

    let(:prod_reader) do
      instance_double(Y2Packager::ProductReader)
    end

    let(:textmode) { true }
    let(:packages_init_called) { true }
    let(:sles_selected) { true }
    let(:sdk_selected) { true }

    before do
      allow(Yast::UI).to receive(:TextMode).and_return(textmode)
      allow(Y2Packager::ProductReader).to receive(:new).and_return(prod_reader)
      allow(prod_reader).to receive(:all_products)
        .with(force_repos: true).and_return(products)
      allow(sles).to receive(:status?).with(:selected).and_return(sles_selected)
      allow(sdk).to receive(:status?).with(:selected).and_return(sdk_selected)
      allow(sles).to receive(:status?).with(:available).and_return(false)
      allow(sdk).to receive(:status?).with(:available).and_return(!sdk_selected)
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

    context "when the Packages module has not been initialized" do
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

      context "when some module is selected" do
        let(:sles_selected) { true }
        let(:sdk_selected) { false }

        it "shows release notes for 'selected' modules" do
          expect(sles).to receive(:release_notes)
          expect(sdk).to_not receive(:release_notes)
          client.main
        end
      end

      context "when no module is selected" do
        let(:sles_selected) { false }
        let(:sdk_selected) { false }

        it "shows release notes for 'available' modules" do
          expect(sles).to_not receive(:release_notes)
          expect(sdk).to receive(:release_notes)
          client.main
        end
      end

      context "when not running on initial stage" do
        let(:other_product) { double("Y2Packager::Product") }
        let(:products) { [other_product, sles, sdk] }

        before do
          allow(Yast::Stage).to receive(:initial).and_return(false)
          allow(other_product).to receive(:status?).with(:selected).and_return(false)
          allow(other_product).to receive(:status?).with(:selected, :installed).and_return(false)
          allow(sles).to receive(:status?).with(:selected, :installed).and_return(true)
          allow(sdk).to receive(:status?).with(:selected, :installed).and_return(true)
        end

        it "shows release notes for 'selected' and 'available' modules" do
          expect(sles).to receive(:release_notes)
          expect(sdk).to receive(:release_notes)
          expect(other_product).to_not receive(:release_notes)
          client.main
        end
      end
    end
  end
end

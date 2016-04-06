#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_disks_activate"

describe Yast::InstDisksActivateClient do
  Yast.import "Arch"
  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"
  Yast.import "GetInstArgs"
  Yast.import "UI"
  Yast.import "Popup"
  Yast.import "Storage"

  describe "#main" do
    let(:probed_disks) { [] }
    let(:s390) { false }

    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("WithFCoE").and_return("0")
      allow(Yast::UI).to receive(:OpenDialog)
      allow(Yast::UI).to receive(:CloseDialog)
      allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(true)
      allow(Yast::Arch).to receive(:s390).and_return(s390)
      allow(Yast::Storage).to receive(:ReReadTargetMap)
    end

    context "when architecture is s390" do
      let(:s390) { true }
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:abort)
      end

      it "detects DASD disks" do
        expect(Yast::SCR).to receive(:Read).with(path(".probe.disk"))
          .and_return(probed_disks)
        allow(Yast::SCR).to receive(:Read).with(path(".probe.storage"))
          .and_return(probed_disks)
        expect(subject).to receive(:show_base_dialog)

        expect(subject.main).to eq(:abort)
      end

      it "detects zFCP disks" do
        allow(Yast::SCR).to receive(:Read).with(path(".probe.disk"))
          .and_return(probed_disks)
        expect(Yast::SCR).to receive(:Read).with(path(".probe.storage"))
          .and_return(probed_disks)
        expect(subject).to receive(:show_base_dialog)

        expect(subject.main).to eq(:abort)
      end
    end

    context "when dasd button is clicked" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:dasd, :abort)
      end

      it "calls inst_dasd client" do
        expect(Yast::WFM).to receive(:call).with("inst_dasd")
        expect(subject).to receive(:show_base_dialog).twice

        subject.main
      end
    end

    context "when network button is clicked" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:network, :abort)
      end

      it "calls inst_lan client" do
        expect(Yast::WFM).to receive(:call).with("inst_lan", ["skip_detection" => true])
        expect(subject).to receive(:show_base_dialog).twice

        subject.main
      end
    end

    context "when abort button is clicked" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:abort)
      end

      it "returns :abort" do
        expect(subject).to receive(:show_base_dialog).once

        expect(subject.main).to eq(:abort)
      end
    end
  end
end

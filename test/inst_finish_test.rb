#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/clients/inst_finish"

describe Yast::InstFinishClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:ClientExists).and_return(true)
      allow(Yast::WFM).to receive(:CallFunction).with(anything, ["Info"]) { Hash.new }
      allow(Yast::WFM).to receive(:CallFunction).with(anything, ["Write"])

      allow(Yast::UI).to receive(:PollInput)

      allow(Yast::Wizard).to receive(:DisableBackButton)
      allow(Yast::Wizard).to receive(:DisableNextButton)

      allow(Yast::SlideShow).to receive(:Setup)
      allow(Yast::SlideShow).to receive(:HaveSlideWidget).and_return(true)
      allow(Yast::SlideShow).to receive(:StageProgress)
      allow(Yast::SlideShow).to receive(:SubProgress)

      allow(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)
      allow(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)

      allow(Yast::Hooks).to receive(:run)
    end

    it "return :next if not aborted" do
      expect(subject.main).to eq :next
    end

    it "return :abort if aborted by user and confirmed" do
      expect(Yast::UI).to receive(:PollInput).and_return(:abort)
      expect(Yast::Popup).to receive(:ConfirmAbort).and_return(true)

      expect(subject.main).to eq :abort
    end

    it "returns :auto if going back in installation" do
      expect(Yast::GetInstArgs).to receive(:going_back).and_return(true)

      expect(subject.main).to eq :auto
    end

    it "disables Back button" do
      expect(Yast::Wizard).to receive(:DisableBackButton)

      subject.main
    end

    it "disables Next button" do
      expect(Yast::Wizard).to receive(:DisableNextButton)

      subject.main
    end

    context "Slide Show handling" do
      it "configure it unless already done" do
        allow(Yast::SlideShow).to receive(:GetSetup).and_return(nil)

        expect(Yast::SlideShow).to receive(:Setup)

        subject.main
      end

      it "opens dialog unless already opened" do
        allow(Yast::SlideShow).to receive(:HaveSlideWidget).and_return(false)

        expect(Yast::SlideShow).to receive(:OpenDialog)

        subject.main
      end

      it "closes dialog if it is opened by method" do
        allow(Yast::SlideShow).to receive(:HaveSlideWidget).and_return(false)

        expect(Yast::SlideShow).to receive(:CloseDialog)

        subject.main
      end

      it "hides table" do
        expect(Yast::SlideShow).to receive(:HideTable)

        subject.main
      end

      it "moves to finish stage" do
        expect(Yast::SlideShow).to receive(:MoveToStage).with("finish")

        subject.main
      end

      it "sets subprogress to 0%" do
        expect(Yast::SlideShow).to receive(:SubProgress).with(0, "")

        subject.main
      end

      it "sets stage progress to 0%" do
        expect(Yast::SlideShow).to receive(:StageProgress).with(0, anything)

        subject.main
      end

      it "sets stage progress to 100% when finished" do
        expect(Yast::SlideShow).to receive(:StageProgress).with(100, anything)

        subject.main
      end
    end

    it "ensures no callbacks during initialization called" do
      expect(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)

      subject.main
    end

    it "restores previously used callbacks afterwards" do
      expect(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)

      subject.main
    end

    it "initializes installation target dir as packager targer" do
      allow(Yast::Installation).to receive(:destdir).and_return("/mnt")

      expect(Yast::Pkg).to receive(:TargetInitialize).with("/mnt")

      subject.main
    end

    it "loads data from packager target" do
      expect(Yast::Pkg).to receive(:TargetLoad)

      subject.main
    end

    context "finish clients" do
      it "Call info for all specified finish clients" do
        expect(Yast::WFM).to receive(:CallFunction).at_least(1).and_return({})

        subject.main
      end

      it "filter out all clients which 'when' key do not match current mode" do
        allow(Yast::Mode).to receive(:update).and_return(true)
        # fake that this client will be called only during common installation, so skipped in update
        client = "bootloader_finish"
        allow(Yast::WFM).to receive(:CallFunction).with(client, ["Info"])
          .and_return("when" => [:installation])

        # so not write can happen
        expect(Yast::WFM).to_not receive(:CallFunction).with(client, ["Write"])

        subject.main
      end

      it "runs before_<client_name> hook" do
        expect(Yast::Hooks).to receive(:run).with("before_bootloader_finish")

        subject.main
      end

      it "runs after_<client_name> hook" do
        expect(Yast::Hooks).to receive(:run).with("after_bootloader_finish")

        subject.main
      end

    end
  end
end

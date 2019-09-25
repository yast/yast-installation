#! /usr/bin/env rspec

require_relative "../../test_helper"

require "installation/clients/pre_umount_finish"

describe ::Installation::PreUmountFinish do
  describe "#write" do
    before do
      allow(Yast::WFM).to receive(:Execute).and_return("exit"=>0)
      allow(Yast::SCR).to receive(:Execute).and_return("exit"=>0)
      # Set the target dir to /mnt
      allow(Yast::WFM).to receive(:Args).and_return("initial")
    end

    it "checks running processes" do
      expect(Yast::WFM).to receive(:Execute).with(anything, /fuser -v/)

      subject.write
    end

    it "beeps if a bootmessage is available" do
      expect(Yast::Misc).to receive(:boot_msg).and_return("bootmessage")
      expect(Yast::SCR).to receive(:Execute).with(anything, /\/bin\/echo -e /)

      subject.write
    end

    it "closes package management" do
      expect(Yast::Pkg).to receive(:SourceReleaseAll)
      expect(Yast::Pkg).to receive(:SourceSaveAll)
      expect(Yast::Pkg).to receive(:TargetFinish)

      subject.write
    end

    context "update mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(true)
      end

      it "does not preserve randomness state" do
        expect(Yast::WFM).not_to receive(:Execute).with(anything, /dd/)

        subject.write
      end
    end

    context "installation mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(false)
      end

      it "does preserve randomness state" do
        expect(Yast::WFM).to receive(:Execute).with(anything, /dd/)

        subject.write
      end
    end
  end
end

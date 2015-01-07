#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/copy_logs_finish"

describe ::Installation::CopyLogsFinish do
  describe "#write" do
    before do
      allow(Yast::WFM).to receive(:Execute)
    end

    it "copies logs from instalation to target system" do
      allow(Yast::WFM).to receive(:Read).and_return(["y2start.log"])

      expect(Yast::WFM).to receive(:Execute).with(anything(), /cp/).at_least(:once)

      subject.write
    end

    it "rotate y2log" do
      allow(Yast::WFM).to receive(:Read).and_return(["y2log-1.gz"])

      expect(Yast::WFM).to receive(:Execute).with(anything(), /cp .*y2log-1.gz .*y2log-2.gz/)

      subject.write
    end

    it "compress y2log if not already done" do
      allow(Yast::WFM).to receive(:Read).and_return(["y2log-1"])

      expect(Yast::WFM).to receive(:Execute).with(anything(), /gzip .*y2log-2/) #-2 due to rotation

      subject.write
    end

    it "rotate zypp.log" do
      allow(Yast::WFM).to receive(:Read).and_return(["zypp.log"])

      expect(Yast::WFM).to receive(:Execute).with(anything(), /cp .*zypp.log .*zypp.log-1/)

      subject.write
    end
  end
end

#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/copy_logs_finish"

describe ::Installation::CopyLogsFinish do
  describe "#write" do
    before do
      allow(Yast::WFM).to receive(:Execute)
      # Set the target dir to /mnt
      allow(Yast::WFM).to receive(:Args).and_return("initial")
    end

    def mock_log_dir(files)
      allow(Yast::WFM).to receive(:Read).and_return(files)
    end

    def expect_to_run(cmd)
      expect(Yast::WFM).to receive(:Execute).with(anything, cmd)
    end

    it "copies logs from instalation to target system" do
      mock_log_dir(["y2start.log"])

      expect_to_run(/cp .*y2start.log.*y2start.log/)

      subject.write
    end

    it "rotates y2log" do
      mock_log_dir(["y2log-1.gz"])

      expect_to_run(/cp .*y2log-1.gz.*\/mnt\/.*y2log-2.gz/)

      subject.write
    end

    it "compresses y2log if not already done" do
      mock_log_dir(["y2log-1"])

      expect_to_run(/gzip .*\/mnt\/.*y2log-2/) #-2 due to rotation

      subject.write
    end

    it "does not get stuck during compress if file already exists (bnc#897091)" do
      mock_log_dir(["y2log-1"])

      expect_to_run(/gzip -f/)

      subject.write
    end

    it "rotates zypp.log" do
      mock_log_dir(["zypp.log"])

      expect_to_run(/cp .*zypp.log.*\/mnt\/.*zypp.log-1/)

      subject.write
    end

    it "copies the storage-inst subdir" do
      mock_log_dir(["storage-inst"])

      expect_to_run(/rm -rf .*\/mnt\/.*storage-inst/)
      expect_to_run(/cp -r .*\/mnt\/.*storage-inst/)

      subject.write
    end
  end
end

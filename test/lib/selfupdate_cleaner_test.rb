# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "installation/selfupdate_cleaner"
require "fileutils"
require "tmpdir"
require "pathname"

describe Installation::SelfupdateCleaner do
  describe "#run" do
    subject(:cleaner) { described_class.new(instsys) }
    let(:instsys) { Pathname.new(Dir.mktmpdir) }

    context "when updates are applied" do

      let(:mounts) { instsys.join("mounts") }
      let(:downloads) { instsys.join("download") }

      before do
        FileUtils.cp_r(fixtures_dir.join("self-update-inst-sys").glob("*"), instsys)
        FileUtils.ln_s(mounts.join("yast_0001"), instsys.join("control.xml"))
      end

      after do
        FileUtils.rm_r(instsys)
      end

      it "removes unused updates" do
        cleaner.run
        expect(mounts.join("yast_0000")).to_not exist
        expect(mounts.join("yast_0001")).to exist
        expect(downloads.join("yast_000")).to_not exist
        expect(downloads.join("yast_001")).to exist
      end

      it "returns the list of unused updates" do
        expect(cleaner.run).to eq(["0000"])
      end
    end

    context "when no updates are applied" do
      it "returns an empty array" do
        expect(cleaner.run).to eq([])
      end
    end

    context "when it is not possible to find out which updates are in use" do
      before do
        allow(Yast::Execute).to receive(:locally!)
          .and_raise(Cheetah::ExecutionFailed.new("", "", "", ""))
      end

      it "returns an empty array" do
        expect(cleaner.run).to eq([])
      end

      it "logs the error" do
        expect(cleaner.log).to receive(:error).with(/which updates are in use/)
        cleaner.run
      end
    end
  end
end

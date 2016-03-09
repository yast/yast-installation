#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/driver_update"
require "open-uri"

Yast.import "Linuxrc"

describe Installation::DriverUpdate do
  TEST_DIR = Pathname.new(__FILE__).dirname
  TEMP_DIR = TEST_DIR.join("test", "tmp", "update")
  FIXTURES_DIR = TEST_DIR.join("fixtures")

  let(:url) { URI("file://#{FIXTURES_DIR}/fake.dud") }

  subject { Installation::DriverUpdate.new(url) }

  before do
    allow(Yast::Linuxrc).to receive(:InstallInf).with("UpdateDir")
      .and_return("/linux/suse/x86_64-sles12")
  end

  after do
    FileUtils.rm_r(TEMP_DIR) if TEMP_DIR.exist?
  end

  describe "#fetch" do
    let(:target) { TEST_DIR.join("target") }

    after do
      FileUtils.rm_r(target) if target.exist? # Make sure the file is removed
    end

    let(:dud_io) { StringIO.new(File.binread(FIXTURES_DIR.join("fake.dud"))) }

    it "downloads the file at #url and stores in the given directory" do
      subject.fetch(target)
      expect(target.join("dud.config")).to be_file
    end

    context "when the remote file does not exists" do
      let(:url) { URI("http://non-existent-url.com/") }

      it "raises an exception" do
        expect { subject.fetch(target) }.to raise_error StandardError
      end
    end
  end

  describe "#apply" do
    let(:local_path) { TEMP_DIR.join("000") }

    context "when the remote file was fetched" do
      before do
        subject.fetch(local_path)
      end

      it "applies the DUD to the running system" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), "/etc/adddir #{local_path}/inst-sys /")
          .and_return("exit" => 0)
        subject.apply
      end
    end

    context "when the remote file was not fetched" do
      let(:local_path) { nil }

      it "raises an exception" do
        expect { subject.apply }.to raise_error(RuntimeError)
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/driver_update"
require "pathname"
require "uri"
require "fileutils"
require "net/http"
require "open-uri"

Yast.import "Linuxrc"

describe Installation::DriverUpdate do
  TEST_DIR = Pathname.new(__FILE__).dirname
  FIXTURES_DIR = TEST_DIR.join("fixtures")

  let(:url) { URI("https://update.opensuse.com/0001.dud") }

  subject { Installation::DriverUpdate.new(url) }

  describe "#fetch" do
    let(:target) { TEST_DIR.join("target") }

    after do
      FileUtils.rm_r(target) if target.exist? # Make sure the file is removed
    end

    let(:dud_io) { StringIO.new(File.binread(FIXTURES_DIR.join("fake.dud"))) }

    it "downloads the file at #url and stores in the given directory" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("UpdateDir")
        .and_return("/linux/suse/x86_64-sles12")
      expect(subject).to receive(:open).with(URI(url)).and_return(dud_io)
      subject.fetch(target)
      expect(target.join("dud.config")).to be_file
    end

    context "when the remote file does not exists" do
      let(:url) { URI("http://non-existent-url.com/") }

      it "raises an exception" do
        expect(subject).to receive(:open).with(url).and_raise(SocketError)
        expect { subject.fetch(target) }.to raise_error SocketError
      end
    end

    context "when the destination directory does not exists" do
      let(:target) { Pathname.pwd.join("non-existent-directory") }

      it "raises an exception" do
        expect { subject.fetch(target) }.to raise_error StandardError
      end
    end
  end

  describe "#apply!" do
    let(:local_path) { Pathname.new("/updates/001") }

    it "applies the DUD to the running system" do
      allow(subject).to receive(:local_path).and_return(local_path)
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), "/etc/adddir #{local_path}/inst-sys /")
        .and_return("exit" => 0)
      subject.apply!
    end

    context "when the remote file was not fetched" do
      let(:local_path) { nil }

      it "raises an exception" do
        expect { subject.apply! }.to raise_error(RuntimeError)
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/driver_update"
require "uri"

Yast.import "Linuxrc"

describe Installation::DriverUpdate do
  TEST_DIR = Pathname.new(__FILE__).dirname
  TEMP_DIR = TEST_DIR.join("test", "tmp", "update")
  FIXTURES_DIR = TEST_DIR.join("fixtures")

  let(:url) { URI("file://#{FIXTURES_DIR}/fake.signed.dud") }
  let(:keyring) { FIXTURES_DIR.join("pubring.gpg") }
  let(:gpg_homedir) { FIXTURES_DIR.join("dot.gnupg") }
  let(:target) { TEST_DIR.join("target") }

  subject { Installation::DriverUpdate.new(url, keyring, gpg_homedir) }

  before do
    allow(Yast::Linuxrc).to receive(:InstallInf).with("UpdateDir")
      .and_return("/linux/suse/x86_64-sles12")
    ::FileUtils.chmod(0700, gpg_homedir)
  end

  after do
    # Make sure those files are removed
    ::FileUtils.rm_r(TEMP_DIR) if TEMP_DIR.exist?
    ::FileUtils.rm_r(target) if target.exist?
  end

  describe "#fetch" do
    let(:url) { URI("file://#{FIXTURES_DIR}/fake.signed.dud") }

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

  describe "#signature" do
    context "if the signature is attached" do
      context "and signature is valid and trusted" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.signed.dud") }

        it "returns :ok" do
          subject.fetch(target)
          expect(subject.signature_status).to eq(:ok)
        end
      end

      context "and signature is valid but not trusted" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.signed+untrusted.dud") }

        it "returns :warning" do
          allow(subject).to receive(:get_file).with(any_args).and_call_original
          allow(subject).to receive(:get_file)
            .with(URI("file://#{FIXTURES_DIR}/fake.signed+untrusted.dud.asc"), any_args).and_return(false)
          subject.fetch(target)
          expect(subject.signature_status).to eq(:warning)
        end
      end

      context "and signature is :error" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.signed+unknown.dud") }

        it "returns false" do
          allow(subject).to receive(:get_file).with(any_args).and_call_original
          allow(subject).to receive(:get_file)
            .with(URI("file://#{FIXTURES_DIR}/fake.signed+unknown.dud.asc"), any_args).once.and_return(false)
          subject.fetch(target)
          expect(subject.signature_status).to eq(:error)
        end
      end
    end

    context "signature is detached" do
      context "and signature is valid and trusted" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.detached.dud") }

        it "returns true" do
          subject.fetch(target)
          expect(subject.signature_status).to eq(:ok)
        end
      end

      context "and signature is valid but not trusted" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.detached+untrusted.dud") }

        it "returns true" do
          subject.fetch(target)
          expect(subject.signature_status).to eq(:warning)
        end
      end

      context "and signature is unknown" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.detached+unknown.dud") }

        it "returns :error" do
          subject.fetch(target)
          expect(subject.signature_status).to eq(:error)
        end
      end

      context "and .asc file does not exist" do
        let(:url) { URI("file://#{FIXTURES_DIR}/fake.dud") }

        before do
          allow(subject).to receive(:get_file).with(any_args).and_call_original
          allow(subject).to receive(:get_file)
            .with(URI("file://#{FIXTURES_DIR}/fake.dud.asc"), any_args).once.and_return(false)
        end

        it "returns :missing" do
          subject.fetch(target)
          expect(subject.signature_status).to eq(:missing)
        end
      end
    end
  end

  describe "#signed?" do
    before { expect(subject).to receive(:signature_status).and_return(status) }

    context "present and good" do
      let(:status) { :ok }

      it "returns true" do
        expect(subject).to be_signed
      end
    end

    context "good but with a warning" do
      let(:status) { :warning }

      it "returns true" do
        expect(subject).to be_signed
      end
    end

    context "signed with and unknown key" do
      let(:status) { :error }

      it "returns false" do
        expect(subject).to_not be_signed
      end
    end

    context "is signature is missing" do
      let(:status) { :missing }

      it "returns false" do
        expect(subject).to_not be_signed
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

#!/usr/bin/env rspec

require_relative "./test_helper"
require "installation/remote_finish_client"

module Yast
  import "WFM"
  import "Linuxrc"

  describe ::Installation::RemoteFinishClient do
    subject { ::Installation::RemoteFinishClient.new }

    describe "#run" do
      it "can be called as a WFM client with 'Info'" do
        allow(Linuxrc).to receive(:vnc)
        result = Yast::WFM.CallFunction("remote_finish", ["Info"])
        expect(result).to be_a(Hash)
        expect(result["steps"]).to eq(1)
      end

      it "can be called as a WFM client with 'Write'" do
        expect_any_instance_of(::Installation::RemoteFinishClient).to receive(:enable_remote)
        expect(Yast::WFM.CallFunction("remote_finish", ["Write"])).to be_nil
      end
    end

    describe "#modes" do
      let(:modes) do
        subject.modes
      end

      context "using VNC" do
        before do
          allow(Linuxrc).to receive(:vnc).and_return true
        end

        it "configures remote access for installation and autoinst" do
          expect(modes.sort).to eq([:autoinst, :installation])
        end
      end

      context "not using VNC " do
        before do
          allow(Linuxrc).to receive(:vnc).and_return false
        end

        it "does not configure remote access" do
          expect(modes).to be_empty
        end
      end
    end

    describe "#enable_remote" do
      it "enables remote access" do
        expect(Remote).to receive(:Write)
        subject.enable_remote
        expect(Remote.IsEnabled).to eql(true)
      end
    end
  end
end

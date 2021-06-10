#! /usr/bin/env rspec

require_relative "./../../test_helper"

require "installation/clients/proxy_finish"

describe Yast::ProxyFinishClient do
  let(:client) { described_class.new }
  let(:func) { "Info" }
  let(:parm) { nil }
  let(:args) { [] }
  let(:func) { args[0] }
  let(:parms) { args[1] }

  before do
    allow(Yast::WFM).to receive(:Args).and_return(args)
    allow(Yast::WFM).to receive(:Args).with(0).and_return(args[0])
    allow(Yast::WFM).to receive(:Args).with(1).and_return(args[1])
  end

  context "when the client is called with 'Info' argument" do
    let(:args) { ["Info"] }

    it "returns a hash" do
      expect(client.main).to be_a(Hash)
    end

    it "returns 1 step with 'Saving proxy configuration...' title" do
      result = client.main
      expect(result["steps"]).to eql(1)
      expect(result["title"]).to eql("Saving proxy configuration...")
    end

    it "returns that the step is valid for :installation, :update and :autoinst modes" do
      expect(client.main["when"]).to include(:installation, :update, :autoinst)
    end
  end

  context "when the client is called with the 'Write' argument" do
    let(:initial_stage) { true }
    let(:to_target) { false }
    let(:modified) { false }
    let(:args) { ["Write"] }
    let(:config) { { "http_proxy" => "http://proxy.example.com:3128/" } }

    before do
      allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
      allow(Yast::Proxy).to receive(:to_target).and_return(to_target)
      allow(Yast::Proxy).to receive(:Export).and_return(config)
      allow(Yast::Proxy).to receive(:modified).and_return(modified)
    end

    context "when running on the first stage" do
      context "and the proxy settings were not written to the inst-sys during the installation" do
        it "does nothing" do
          expect(Yast::Proxy).to_not receive(:WriteSysconfig)
          expect(Yast::Proxy).to_not receive(:WriteCurlrc)
          client.main
        end
      end

      context "and the proxy settings have been modified but not written yet" do
        let(:modified) { true }

        it "writes the current sysconfig and curlrc configuration to the target system" do
          expect(Yast::Proxy).to receive(:Import).with(config)
          expect(Yast::Proxy).to receive(:WriteSysconfig)
          expect(Yast::Proxy).to receive(:WriteCurlrc)
          client.main
        end
      end

      context "and the proxy settings were written to the inst-sys during the installation" do
        let(:to_target) { true }

        it "writes the current sysconfig and curlrc configuration to the target system" do
          expect(Yast::Proxy).to receive(:Import).with(config)
          expect(Yast::Proxy).to receive(:WriteSysconfig)
          expect(Yast::Proxy).to receive(:WriteCurlrc)
          client.main
        end
      end
    end
  end
end

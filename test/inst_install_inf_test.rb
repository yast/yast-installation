#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_install_inf"

describe Yast::InstInstallInfClient do

  before do
    allow(Yast::InstallInfConvertor.instance).to receive(:write_netconfig)
    allow(Yast::SCR).to receive(:Read)
    allow(Yast::SCR).to receive(:Write)
    allow(Yast::Linuxrc).to receive(:InstallInf)
    allow(Yast::Mode).to receive(:auto)
  end

  describe "#main" do
    it "writes the network configuration given by linuxrc" do
      expect(Yast::InstallInfConvertor.instance).to receive(:write_netconfig)

      subject.main
    end

    context "when a regurl is provided by linuxrc" do
      let(:invalid_url) { "http://wrong_url{}.com" }
      let(:valid_url) { "http://scc.custom.com" }

      it "allows the user to fix it it's invalid" do
        expect(Yast::Linuxrc).to receive(:InstallInf).with("regurl").and_return(invalid_url)
        expect(subject).to receive(:fix_regurl!).with(invalid_url)

        subject.main
      end

      it "does nothing with the url in case of valid" do
        expect(Yast::Linuxrc).to receive(:InstallInf).with("regurl").and_return(valid_url)
        expect(subject).to_not receive(:fix_regurl!)

        subject.main
      end
    end

    it "returns :next" do
      expect(subject.main).to eq(:next)
    end
  end
end

#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/ntp_server"

describe ::Installation::Widgets::NtpServer do
  subject(:widget) { ::Installation::Widgets::NtpServer.new }
  let(:dashboard_role) { ::Installation::SystemRole.new(id: "dashboard_role") }

  before do
    allow(::Installation::SystemRole).to receive(:find)
      .with("dashboard_role").and_return(dashboard_role)
  end

  describe "#label" do
    it "returns 'NTP Servers'" do
      expect(widget.label).to eq("NTP Servers")
    end
  end

  describe "#init" do
    let(:ntp_servers) { [] }

    before do
      allow(Yast::SlpService).to receive(:all).and_return(ntp_servers)
    end

    it "reads initial value from dashboard role" do
      allow(dashboard_role).to receive(:[]).with("ntp_servers")
        .and_return(["server1"])
      expect(widget).to receive(:value=).with("server1")
      widget.init
    end

    context "when some NTP server is found via SLP" do
      let(:ntp_servers) do
        [
          double("server1", slp_url: "service:ntp://server1.lan:123,65535"),
          double("server2", slp_url: "service:ntp://server2.lan:123,65535")
        ]
      end

      it "sets those servers as the default value" do
        expect(widget).to receive(:value=).with("server1.lan server2.lan")
        widget.init
      end
    end
  end

  describe "#store" do
    before do
      allow(widget).to receive(:value).and_return(value)
    end

    context "when value is an empty" do
      let(:value) { "" }

      it "sets the role ntp_servers property to an empty array" do
        widget.store
        expect(dashboard_role["ntp_servers"]).to eq([])
      end
    end

    context "when value is a hostname/address" do
      let(:value) { "server1" }

      it "sets the role ntp_servers property to an array containing the hostname/address" do
        widget.store
        expect(dashboard_role["ntp_servers"]).to eq(["server1"])
      end
    end

    context "when more than one hostname/address separated by spaces" do
      let(:value) { "server1 server2" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        widget.store
        expect(dashboard_role["ntp_servers"]).to eq(["server1", "server2"])
      end
    end

    context "when more than one hostname/address separated by commas" do
      let(:value) { "server1,server2" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        widget.store
        expect(dashboard_role["ntp_servers"]).to eq(["server1", "server2"])
      end
    end

    context "when more than one hostname/address separated by mixed spaces and commas" do
      let(:value) { "server1,server2 server3" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        widget.store
        expect(dashboard_role["ntp_servers"]).to eq(["server1", "server2", "server3"])
      end
    end
  end

  describe "#validate" do
    before do
      allow(widget).to receive(:value).and_return(value)
    end

    context "when valid IP addresses are provided" do
      let(:value) { "192.168.122.1 10.0.0.1" }

      it "returns true" do
        expect(widget.validate).to eq(true)
      end
    end

    context "when valid hostnames are provided" do
      let(:value) { "ntp.suse.de ntp.suse.cz" }

      it "returns true" do
        expect(widget.validate).to eq(true)
      end
    end

    context "when non valid addresses/hostnames are provided" do
      let(:value) { "ntp.suse.de ***" }

      it "returns false" do
        allow(Yast::Popup).to receive(:Error)
        expect(widget.validate).to eq(false)
      end

      it "reports the problem to the user" do
        expect(Yast::Popup).to receive(:Error)
        widget.validate
      end
    end

    context "when no value is provided" do
      let(:value) { "" }

      it "returns false" do
        expect(widget.validate).to eq(false)
      end
    end
  end
end

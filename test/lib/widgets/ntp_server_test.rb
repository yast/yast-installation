#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/ntp_server"
require "cwm/rspec"

describe ::Installation::Widgets::NtpServer do
  subject(:widget) { ::Installation::Widgets::NtpServer.new }
  let(:dashboard_role) { ::Installation::SystemRole.new(id: "dashboard_role", order: "100") }

  before do
    allow(::Installation::SystemRole).to receive(:current_role).and_return(dashboard_role)
  end

  include_examples "CWM::AbstractWidget"

  describe "#init" do
    subject(:widget) { ::Installation::Widgets::NtpServer.new(["ntp.suse.de"]) }

    it "reads initial value from dashboard role" do
      allow(dashboard_role).to receive(:[]).with("ntp_servers")
        .and_return(["server1"])
      expect(widget).to receive(:value=).with("server1")
      widget.init
    end

    context "when dashboard role does not define any server" do
      it "uses the default servers" do
        expect(widget).to receive(:value=).with("ntp.suse.de")
        widget.init
      end
    end
  end

  describe "#store" do
    let(:value) { "" }

    let(:ntp_conf) { double("ntp conf") }

    before do
      allow(widget).to receive(:value).and_return(value)

      allow(Yast::NtpClient).to receive(:modified=)
      allow(Yast::NtpClient).to receive(:ntp_selected=)
      allow(Yast::NtpClient).to receive(:ntp_conf).and_return(ntp_conf)
      allow(ntp_conf).to receive(:clear_pools)
      allow(ntp_conf).to receive(:add_pool)
      allow(Yast::NtpClient).to receive(:run_service=)
      allow(Yast::NtpClient).to receive(:synchronize_time=)
    end

    context "when value is empty" do
      it "sets the role ntp_servers property to an empty array" do
        expect(ntp_conf).to_not receive(:add_pool)
        widget.store
      end
    end

    context "when value is a hostname/address" do
      let(:value) { "server1" }

      it "sets the role ntp_servers property to an array containing the hostname/address" do
        expect(ntp_conf).to receive(:add_pool).with(value)
        widget.store
      end
    end

    context "when several hostnames/addresses separated by spaces" do
      let(:value) { "server1 server2" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        expect(ntp_conf).to receive(:add_pool).with("server1")
        expect(ntp_conf).to receive(:add_pool).with("server2")
        widget.store
      end
    end

    context "when several hostnames/addresses separated by commas" do
      let(:value) { "server1,server2" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        expect(ntp_conf).to receive(:add_pool).with("server1")
        expect(ntp_conf).to receive(:add_pool).with("server2")
        widget.store
      end
    end

    context "when more than one hostname/address separated by mixed spaces and commas" do
      let(:value) { "server1,server2 server3" }

      it "sets the role ntp_servers property to an array containing all the hostnames/addresses" do
        expect(ntp_conf).to receive(:add_pool).with("server1")
        expect(ntp_conf).to receive(:add_pool).with("server2")
        expect(ntp_conf).to receive(:add_pool).with("server3")
        widget.store
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

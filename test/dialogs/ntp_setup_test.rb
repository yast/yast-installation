#! /usr/bin/env rspec

require_relative "../test_helper.rb"
require "cwm/rspec"

require "installation/dialogs/ntp_setup"

Yast.import "CWM"
Yast.import "Lan"
Yast.import "Wizard"

describe ::Installation::Dialogs::NtpSetup do
  describe "#run" do
    let(:ntp_servers) { [] }

    before do
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::CWM).to receive(:show).and_return(:next)
      allow(Yast::Lan).to receive(:ReadWithCacheNoGUI)
      allow(Yast::LanItems).to receive(:dhcp_ntp_servers).and_return({})
      allow(Yast::ProductFeatures).to receive(:GetBooleanFeature)
    end

    include_examples "CWM::Dialog"

    context "when some NTP server is detected via DHCP" do
      let(:ntp_servers) { ["ntp.example.com"] }

      it "proposes to use it by default" do
        expect(Yast::LanItems).to receive(:dhcp_ntp_servers).and_return("eth0" => ntp_servers)
        expect(::Installation::Widgets::NtpServer).to receive(:new)
          .with(ntp_servers).and_call_original
        subject.run
      end
    end

    context "no NTP server set in DHCP and default NTP is enabled in control.xml" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeature)
          .with("globals", "default_ntp_setup").and_return(true)
        allow(Yast::Product).to receive(:FindBaseProducts)
          .and_return(["name" => "openSUSE-Tumbleweed-Kubic"])
      end

      it "proposes to use a random openSUSE pool server" do
        expect(::Installation::Widgets::NtpServer).to receive(:new)
          .and_wrap_original do |original, arg|
            expect(arg.first).to match(/\A[0-3]\.opensuse\.pool\.ntp\.org\z/)
            original.call(arg)
          end
        subject.run
      end
    end
  end
end

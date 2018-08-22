#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../support/fake_registration"
require "installation/update_repositories_finder"
require "uri"

Yast.import "Linuxrc"

describe Installation::UpdateRepositoriesFinder do
  describe "#updates" do
    let(:url_from_linuxrc) { nil }
    let(:url_from_control) { "http://update.opensuse.org/\$arch/42.2" }
    let(:real_url_from_control) { "http://update.opensuse.org/#{arch}/42.2" }
    let(:arch) { "armv7hl" }
    let(:profile) { {} }
    let(:ay_profile) { double("Yast::Profile", current: profile) }
    let(:repo) { double("UpdateRepository") }
    let(:self_update_in_cmdline) { false }

    subject(:finder) { described_class.new }

    before do
      stub_const("Yast::Profile", ay_profile)
      stub_const("::Registration::ConnectHelpers", FakeConnectHelpers)
      allow(finder).to receive(:require).with("registration/connect_helpers")
      allow(Yast::InstFunctions).to receive("self_update_in_cmdline?")
        .and_return(self_update_in_cmdline)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate")
        .and_return(url_from_linuxrc)
      allow(Yast::Pkg).to receive(:GetArchitecture).and_return(arch)
    end

    context "when URL was specified via Linuxrc" do
      let(:url_from_linuxrc) { "http://example.net/sles12/" }

      it "returns the updates repository using the URL from Linuxrc" do
        expect(Installation::UpdateRepository).to receive(:new)
          .with(URI(url_from_linuxrc), :user).and_return(repo)
        expect(finder.updates).to eq([repo])
      end
    end

    context "when URL was specified via an AutoYaST profile" do
      let(:profile_url) { "http://ay.test.example.com/update" }
      let(:profile) { { "general" => { "self_update_url" => profile_url } } }

      before do
        allow(Yast::Mode).to receive(:auto).and_return(true)
      end

      it "returns the updates repository using the custom URL from the profile" do
        expect(Installation::UpdateRepository).to receive(:new)
          .with(URI(profile_url), :user).and_return(repo)
        expect(finder.updates).to eq([repo])
      end
    end

    context "when no custom URL is specified" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature)
          .with("globals", "self_update_url")
          .and_return(url_from_control)
        # TODO: test don't mock!
        allow(finder).to receive(:add_installation_repo)
        allow(Yast::Linuxrc).to receive(:InstallInf).with("regurl")
          .and_return(nil)
      end

      context "when system is not registrable" do
        before do
          hide_const("::Registration::UrlHelpers")
        end

        it "gets the URL from the control file" do
          expect(Installation::UpdateRepository).to receive(:new)
            .with(URI(real_url_from_control), :default).and_return(repo)
          expect(finder.updates).to eq([repo])
        end
      end

      context "when a SCC/SMT server defines the URL" do
        let(:smt0) { double("service", slp_url: "http://update.suse.com") }
        let(:smt1) { double("service", slp_url: "http://update.example.net") }

        let(:update0) do
          OpenStruct.new(
            name: "SLES-12-Installer-Updates-0",
            url:  "http://update.suse.com/updates/sle12/12.2"
          )
        end

        let(:update1) do
          OpenStruct.new(
            name: "SLES-12-Installer-Updates-1",
            url:  "http://update.suse.com/updates/sles12/12.2"
          )
        end

        let(:regservice_selection) { Class.new }

        let(:url_helpers) { double("url_helpers", registration_url: smt0.slp_url, slp_discovery: []) }
        let(:regurl) { nil }

        let(:registration) { double("registration", url: smt0.slp_url) }
        let(:registration_class) { double("registration_class", new: registration) }

        let(:updates) { [update0] }

        before do
          stub_const("Registration::Registration", registration_class)
          stub_const("Registration::UrlHelpers", url_helpers)
          stub_const("Registration::UI::RegserviceSelectionDialog", regservice_selection)
          stub_const("Registration::Storage::InstallationOptions", FakeInstallationOptions)

          allow(url_helpers).to receive(:service_url) { |u| u }
          allow(url_helpers).to receive(:boot_reg_url).and_return(regurl)
          allow(registration).to receive(:get_updates_list).and_return(updates)
        end

        it "gets the URL defined by the server" do
          expect(Installation::UpdateRepository).to receive(:new)
            .with(URI(update0.url), :default).and_return(repo)
          expect(finder.updates).to eq([repo])
        end

        context "when the registration server returns an empty list" do
          let(:updates) { [] }

          it "falls back to use updates URL defined in the control file" do
            expect(Installation::UpdateRepository).to receive(:new)
              .with(URI(real_url_from_control), :default).and_return(repo)
            expect(finder.updates).to eq([repo])
          end
        end

        context "when more than one SMT server is found via SLP" do
          before do
            allow(url_helpers).to receive(:slp_discovery).and_return([smt0, smt1])
          end

          context "if the user selects a SMT server" do
            before do
              allow(regservice_selection).to receive(:run).and_return(smt0)
            end

            it "asks the SMT server for the updates URLs" do
              expect(registration_class).to receive(:new).with(smt0.slp_url)
                .and_return(registration)
              expect(Installation::UpdateRepository).to receive(:new)
                .with(URI(update0.url), :default).and_return(repo)
              finder.updates
            end

            it "handles registration errors" do
              expect(Registration::ConnectHelpers).to receive(:catch_registration_errors)
                .and_call_original
              finder.updates
            end
          end

          context "if user cancels the dialog" do
            before do
              allow(regservice_selection).to receive(:run).and_return(:cancel)
            end

            it "falls back to use updates URL defined in the control file" do
              expect(registration).to_not receive(:get_updates_list)
              expect(Installation::UpdateRepository).to receive(:new)
                .with(URI(real_url_from_control), :default).and_return(repo)
              expect(finder.updates).to eq([repo])
            end
          end
        end

        context "if users selects the SCC server" do
          before do
            allow(regservice_selection).to receive(:run).and_return(:scc)
          end

          it "asks the SCC server for the updates URLs" do
            expect(registration_class).to receive(:new).with(nil)
              .and_return(registration)
            expect(registration).to receive(:get_updates_list)
              .and_return([update1])
            expect(Installation::UpdateRepository).to receive(:new)
              .with(URI(update1.url), :default).and_return(repo)
            finder.updates
          end

          context "and enables the installer update explicitly by linuxrc" do
            let(:self_update_in_cmdline) { true }

            it "handles registration errors" do
              expect(Registration::ConnectHelpers).to receive(:catch_registration_errors)
                .and_call_original
              finder.updates
            end
          end

          context "and enables the installer update explicitly by an AutoYaST profile" do
            let(:profile) { { "general" => { "self_update" => true } } }

            it "handles registration errors" do
              allow(Yast::Mode).to receive(:auto).and_return(true)
              allow(finder).to receive(:import_registration_ayconfig)
              expect(Registration::ConnectHelpers).to receive(:catch_registration_errors)
                .and_call_original
              finder.updates
            end
          end

          context "and does not enable the installer update explicitly" do
            it "does not handle registration errors" do
              expect(Registration::ConnectHelpers).to_not receive(:catch_registration_errors)
              finder.updates
            end
          end
        end

        context "when a valid regurl was specified via Linuxrc" do
          let(:regurl) { "http://regserver.example.net" }

          it "asks the SCC server for the updates URLs" do
            expect(registration_class).to receive(:new).with(regurl)
              .and_return(registration)
            expect(finder).not_to receive(:update_from_control)

            finder.updates
          end

          it "handles registration errors" do
            expect(Registration::ConnectHelpers).to receive(:catch_registration_errors)
              .and_call_original
            finder.updates
          end
        end

        context "when a invalid regurl was specified via Linuxrc" do
          let(:regurl) { "http://wrong{}regserver.example.net" }

          it "raises an RegistrationURLError exception" do
            expect(registration_class).not_to receive(:new).with(regurl)

            expect { finder.updates }.to raise_error(Installation::RegistrationURLError)
          end
        end
      end
    end
  end
end

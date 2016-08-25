#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"
require "singleton"

describe Yast::InstUpdateInstaller do
  # Registration::Storage::InstallationOptions fake
  class FakeInstallationOptions
    include Singleton
    attr_accessor :custom_url
  end

  class FakeRegConfig
    include Singleton
    def import(_args); end
  end

  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"
  Yast.import "GetInstArgs"
  Yast.import "UI"

  let(:manager) do
    double("update_manager", all_signed?: all_signed?, apply_all: true,
      repositories?: has_repos)
  end
  let(:url) { "http://update.opensuse.org/\$arch/update.dud" }
  let(:real_url) { "http://update.opensuse.org/#{arch}/update.dud" }
  let(:arch) { "x86_64" }
  let(:all_signed?) { true }
  let(:network_running) { true }
  let(:repo) { double("repo") }
  let(:has_repos) { true }
  let(:restarting) { false }
  let(:profile) { {} }
  let(:ay_profile) { double("Yast::Profile", current: profile) }
  let(:ay_profile_location) { double("Yast::ProfileLocation") }

  before do
    allow(Yast::GetInstArgs).to receive(:going_back).and_return(false)
    allow(Yast::Pkg).to receive(:GetArchitecture).and_return(arch)
    allow(Yast::Mode).to receive(:auto).and_return(false)
    allow(Yast::NetworkService).to receive(:isNetworkRunning).and_return(network_running)
    allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
    allow(Yast::Installation).to receive(:restarting?).and_return(restarting)
    allow(Yast::Installation).to receive(:finish_restarting!)
    allow(Yast::Installation).to receive(:restart!) { :restart_yast }
    allow(subject).to receive(:require).with("registration/url_helpers").and_raise(LoadError)
    allow(::FileUtils).to receive(:touch)
    stub_const("Registration::Storage::InstallationOptions", FakeInstallationOptions)
    stub_const("Registration::Storage::Config", FakeRegConfig)
    # skip the libzypp initialization globally, enable in the specific tests
    allow(subject).to receive(:initialize_packager).and_return(true)
    allow(subject).to receive(:finish_packager)
    allow(subject).to receive(:fetch_profile).and_return(ay_profile)
    allow(subject).to receive(:process_profile)

    # stub the Profile module to avoid dependency on autoyast2-installation
    stub_const("Yast::Profile", ay_profile)
  end

  describe "#main" do
    context "when returning back from other dialog" do
      before do
        allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)
      end

      it "returns :back " do
        expect(subject.main).to eq(:back)
      end
    end

    it "initializes the package management" do
      # override the global stub
      expect(subject).to receive(:initialize_packager).and_call_original

      url = "cd:///"
      expect(Yast::Pkg).to receive(:SetTextLocale)
      expect(Yast::Packages).to receive(:ImportGPGKeys)
      expect(Yast::InstURL).to receive(:installInf2Url).and_return(url)
      expect(Yast::Pkg).to receive(:SourceCreateBase).with(url, "").and_return(0)

      # just a shortcut to avoid mocking the whole update
      allow(subject).to receive(:self_update_enabled?).and_return(false)
      subject.main
    end

    it "cleans up the package management at the end" do
      # override the global stub
      expect(subject).to receive(:finish_packager).and_call_original

      expect(Yast::Pkg).to receive(:SourceGetCurrent).and_return([0])
      expect(Yast::Pkg).to receive(:SourceDelete).with(0)
      expect(Yast::Pkg).to receive(:SourceSaveAll)

      # just a shortcut to avoid mocking the whole update
      allow(subject).to receive(:self_update_enabled?).and_return(false)
      subject.main
    end

    it "displays a progress" do
      expect(Yast::Wizard).to receive(:CreateDialog)
      expect(Yast::Progress).to receive(:New)
      expect(Yast::Progress).to receive(:NextStage)

      # just a shortcut to avoid mocking the whole update
      allow(subject).to receive(:self_update_enabled?).and_return(false)
      subject.main
    end

    it "finishes the progress at the end" do
      expect(Yast::Progress).to receive(:Finish)
      expect(Yast::Wizard).to receive(:CloseDialog)

      # just a shortcut to avoid mocking the whole update
      allow(subject).to receive(:self_update_enabled?).and_return(false)
      subject.main
    end

    context "when update URL is configured in control.xml" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return(url)
      end

      context "and update works" do
        before do
          allow(subject).to receive(:update_installer).and_return(true)
        end

        it "creates update file and returns :restart_yast" do
          expect(::FileUtils).to receive(:touch).once
          allow(subject).to receive(:self_update_enabled?).and_return(true)
          expect(subject.main).to eq(:restart_yast)
        end
      end

      context "and update fails" do
        before do
          allow(subject).to receive(:update_installer).and_return(false)
        end

        it "does not create any file and returns :next" do
          expect(::FileUtils).to_not receive(:touch)
          expect(subject.main).to eq(:next)
        end
      end

      context "when the update cannot be fetched" do
        it "shows an error and returns :next" do
          expect(Yast::Popup).to receive(:Error)
          expect(manager).to receive(:add_repository)
            .and_raise(::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo)
          expect(subject.main).to eq(:next)
        end
      end

      context "when repository is empty" do
        let(:has_repos) { false }

        it "does not restart YaST" do
          expect(manager).to receive(:add_repository)
            .and_return(false)
          expect(subject.main).to eq(:next)
        end
      end

      context "when repository can't be probed" do
        before do
          allow(manager).to receive(:add_repository)
            .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
        end

        context "and self-update URL is remote" do
          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to receive(:YesNo)
            expect(manager).to receive(:add_repository)
              .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
            expect(subject.main).to eq(:next)
          end

          context "in AutoYaST installation or upgrade" do
            before do
              allow(Yast::Mode).to receive(:auto).at_least(1).and_return(true)
            end

            it "shows an error" do
              expect(Yast::Report).to receive(:Warning)
              expect(subject.main).to eq(:next)
            end
          end
        end

        context "and self-update URL is not remote" do
          let(:url) { "cd:/?device=sr0" }

          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(manager).to receive(:add_repository)
              .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
            expect(subject.main).to eq(:next)
          end
        end
      end

      context "when an URL is specified through Linuxrc" do
        let(:custom_url) { "http://example.net/sles12/" }

        before do
          allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return(custom_url)
        end

        it "tries to update the installer using the given URL" do
          expect(manager).to receive(:add_repository).with(URI(custom_url)).and_return(true)
          expect(manager).to receive(:apply_all)
          allow(::FileUtils).to receive(:touch)
          expect(subject.main).to eq(:restart_yast)
        end

        it "shows an error if update is not found" do
          expect(Yast::Popup).to receive(:Error)
          expect(manager).to receive(:add_repository).with(URI(custom_url))
            .and_raise(::Installation::UpdatesManager::NotValidRepo)
          expect(subject.main).to eq(:next)
        end
      end

      context "when no URL is specified through Linuxrc" do
        before do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return(url)
        end

        context "in standard installation" do
          it "gets URL from control file" do
            allow(::FileUtils).to receive(:touch)
            expect(manager).to receive(:add_repository).with(URI(real_url)).and_return(true)
            expect(subject.main).to eq(:restart_yast)
          end

          it "does not show an error if update is not found" do
            expect(Yast::Popup).to_not receive(:Error)
            expect(manager).to receive(:add_repository).with(URI(real_url))
              .and_raise(::Installation::UpdatesManager::NotValidRepo)
            expect(subject.main).to eq(:next)
          end

          context "and control file doesn't have an URL" do
            let(:url) { "" }

            it "does not update the installer" do
              expect(subject).to_not receive(:update_installer)
            end
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

          let(:updates) { [update0, update1] }

          before do
            # Load registration libraries
            allow(subject).to receive(:require).with("registration/url_helpers")
              .and_return(true)
            allow(subject).to receive(:require).with("registration/registration")
              .and_return(true)
            allow(subject).to receive(:require).with("registration/ui/regservice_selection_dialog")
              .and_return(true)
            stub_const("Registration::Registration", registration_class)
            stub_const("Registration::UrlHelpers", url_helpers)
            stub_const("Registration::UI::RegserviceSelectionDialog", regservice_selection)

            allow(url_helpers).to receive(:service_url) { |u| u }
            allow(url_helpers).to receive(:boot_reg_url).and_return(regurl)
            allow(registration).to receive(:get_updates_list).and_return(updates)
            allow(manager).to receive(:add_repository).and_return(true)
            allow(File).to receive(:write)
          end

          it "tries to update the installer using the given URL" do
            expect(manager).to receive(:add_repository).with(URI(update0.url))
              .and_return(true)
            expect(manager).to receive(:add_repository).with(URI(update1.url))
              .and_return(true)
            expect(subject.main).to eq(:restart_yast)
          end

          context "when more than one SMT server exist" do
            before do
              allow(url_helpers).to receive(:slp_discovery).and_return([smt0, smt1])
            end

            context "if the user selects a SMT server" do
              before do
                allow(regservice_selection).to receive(:run).and_return(smt0)
              end

              it "asks that SMT server for the updates URLs" do
                expect(registration_class).to receive(:new).with(smt0.slp_url)
                  .and_return(registration)
                allow(manager).to receive(:add_repository)
                subject.main
              end

              it "saves the registration URL to be used later" do
                allow(manager).to receive(:add_repository)
                expect(FakeInstallationOptions.instance).to receive(:custom_url=).with(smt0.slp_url)
                expect(File).to receive(:write).with(/\/inst_update_installer.yaml\z/,
                  { "custom_url" => smt0.slp_url }.to_yaml)
                subject.main
              end
            end

            context "if user cancels the dialog" do
              before do
                allow(regservice_selection).to receive(:run).and_return(:cancel)
                allow(manager).to receive(:add_repository) # it will use the default URL
              end

              it "does not search for updates" do
                expect(registration).to_not receive(:get_updates_list)
                subject.main
              end
            end

            context "if users selects the SCC server" do
              before do
                allow(regservice_selection).to receive(:run).and_return(:scc)
              end

              it "asks the SCC server for the updates URLs" do
                expect(registration_class).to receive(:new).with(nil)
                  .and_return(registration)
                allow(manager).to receive(:add_repository)
                subject.main
              end

              it "does not save the registration URL to be used later" do
                allow(manager).to receive(:add_repository)
                allow(registration).to receive(:url).and_return(nil)
                expect(FakeInstallationOptions.instance).to receive(:custom_url=).with(nil)
                expect(File).to_not receive(:write).with(/inst_update_installer.yaml/, anything)
                subject.main
              end
            end

            context "when a regurl was specified via Linuxrc" do
              let(:regurl) { "http://regserver.example.net" }

              it "uses the given server" do
                expect(registration_class).to receive(:new).with(regurl)
                  .and_return(registration)
                subject.main
              end
            end
          end

          context "when a registration configuration is specified via AutoYaST profile" do
            let(:reg_server_url) { "http://ay.test.example.com/update" }
            let(:profile) { { "suse_register" => { "reg_server" => reg_server_url } } }

            before do
              allow(Yast::Mode).to receive(:auto).at_least(1).and_return(true)
            end

            it "uses the given server" do
              expect(registration_class).to receive(:new).with(reg_server_url)
                .and_return(registration)
              subject.main
            end

            it "imports profile settings into registration configuration" do
              allow(manager).to receive(:add_repository)
              expect(FakeRegConfig.instance).to receive(:import).with(profile["suse_register"])
              subject.main
            end
          end
        end

        context "in AutoYaST installation or upgrade" do
          let(:profile_url) { "http://ay.test.example.com/update" }
          let(:profile) { { "general" => { "self_update_url" => profile_url } } }

          before do
            expect(Yast::Mode).to receive(:auto).at_least(1).and_return(true)
            allow(::FileUtils).to receive(:touch)
          end

          it "tries to process the profile from the given URL" do
            expect(subject).to receive(:process_profile)
            expect(manager).to receive(:add_repository).with(URI(profile_url))
              .and_return(true)

            subject.main
          end

          context "the profile defines the update URL" do
            it "gets the URL from AutoYaST profile" do
              expect(manager).to receive(:add_repository).with(URI(profile_url))
                .and_return(true)
              subject.main
            end

            it "returns :restart_yast" do
              allow(manager).to receive(:add_repository).with(URI(profile_url))
                .and_return(true)
              expect(subject.main).to eq(:restart_yast)
            end

            it "shows an error and returns :next if update fails" do
              expect(Yast::Report).to receive(:Error)
              expect(manager).to receive(:add_repository)
                .and_raise(::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo)
              expect(subject.main).to eq(:next)
            end
          end

          context "the profile does not define the update URL" do
            let(:profile_url) { nil }

            it "gets URL from control file" do
              expect(manager).to receive(:add_repository).with(URI(real_url))
                .and_return(true)
              expect(subject.main).to eq(:restart_yast)
            end

            it "does not show an error if update is not found" do
              expect(Yast::Report).to_not receive(:Error)
              expect(manager).to receive(:add_repository).with(URI(real_url))
                .and_raise(::Installation::UpdatesManager::NotValidRepo)
              expect(subject.main).to eq(:next)
            end

            context "and control file doesn't have an URL" do
              let(:url) { "" }

              it "does not update the installer" do
                expect(subject).to_not receive(:update_installer)
                expect(subject.main).to eq(:next)
              end
            end
          end
        end
      end

      context "when network is not available" do
        let(:network_running) { false }

        it "does not update the installer" do
          expect(subject).to_not receive(:update_installer)
          expect(subject.main).to eq(:next)
        end
      end

      context "when a error happens while applying the update" do
        it "does not catch the exception" do
          expect(manager).to receive(:add_repository)
            .and_return(true)
          expect(manager).to receive(:apply_all)
            .and_raise(StandardError)
          expect { subject.update_installer }.to raise_error(StandardError)
        end
      end
    end

    context "when update is disabled through Linuxrc" do
      it "does not update the installer" do
        expect(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return("0")
        expect(subject).to_not receive(:update_installer)
        expect(subject.main).to eq(:next)
      end
    end

    context "when restarting YaST2" do
      let(:restarting) { true }
      let(:data_file_exists) { true }
      let(:smt_url) { "https://smt.example.net" }
      let(:registration_libs) { true }

      before do
        allow(File).to receive(:exist?)
        allow(File).to receive(:exist?).with(/\/inst_update_installer.yaml\z/)
          .and_return(data_file_exists)
        allow(subject).to receive(:require_registration_libraries)
          .and_return(registration_libs)
        allow(File).to receive(:exist?).with(/installer_updated/).and_return(true)
      end

      context "and data file is available" do
        it "sets custom_url" do
          allow(File).to receive(:read).and_return("---\ncustom_url: #{smt_url}\n")
          expect(FakeInstallationOptions.instance).to receive(:custom_url=)
            .with(smt_url)
          subject.main
        end
      end

      context "and data file is not available" do
        let(:data_file_exists) { false }

        it "does not set custom_url" do
          expect(FakeInstallationOptions.instance).to_not receive(:custom_url=)
          subject.main
        end
      end

      context "and yast2-registration is not available" do
        let(:registration_libs) { false }

        it "does not load custom_url" do
          expect(FakeInstallationOptions.instance).to_not receive(:custom_url=)
          subject.main
        end
      end
    end
  end

  describe "#update_installer" do
    let(:update_result) { true }
    let(:insecure) { "0" }

    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("Insecure").and_return(insecure)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate")
        .and_return(url)
    end

    context "when update works" do
      it "returns true" do
        allow(manager).to receive(:add_repository).and_return(true)
        allow(manager).to receive(:apply_all)
        expect(subject.update_installer).to eq(true)
      end
    end
  end
end

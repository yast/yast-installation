#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"

describe Yast::InstUpdateInstaller do
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

  before do
    allow(Yast::Pkg).to receive(:GetArchitecture).and_return(arch)
    allow(Yast::Mode).to receive(:auto).and_return(false)
    allow(Yast::NetworkService).to receive(:isNetworkRunning).and_return(network_running)
    allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
    allow(Yast::Installation).to receive(:restarting?)
    allow(Yast::Installation).to receive(:restart!) { :restart_yast }
    allow(subject).to receive(:require).with("registration/sw_mgmt").and_raise(LoadError)

    # stub the Profile module to avoid dependency on autoyast2-installation
    ay_profile = double("Yast::Profile")
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

    context "when update is enabled" do
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
        context "and self-update URL is remote" do
          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to receive(:YesNo).with(/installer updates from/)
            expect(manager).to receive(:add_repository)
              .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
            expect(subject.main).to eq(:next)
          end
        end

        context "and self-update URL is not remote" do
          let(:url) { "cd:/?device=sr0" }
          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(manager).to receive(:add_repository).and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
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

        context "when SMT defines the URL" do
          let(:update_url) { "http://update.suse.com/sle12/12.2" }
          let(:smt_url) { "http://update.suse.com" }

          let(:base_product) do
            {
              "arch"         => "x86_64",
              "name"         => "SLES",
              "version"      => "12-2",
              "release_type" => ""
            }
          end

          let(:product) do
            OpenStruct.new(
              arch:         base_product["arch"],
              identifier:   base_product["name"],
              version:      base_product["version"],
              release_type: base_product["release_type"]
            )
          end

          let(:update) { OpenStruct.new(name: "SLES-12-Installer-Updates", url: update_url) }

          let(:sw_mgmt) do
            double("sw_mgmt", base_product_to_register: base_product,
                              remote_product:           product)
          end

          let(:suse_connect) do
            double("suse_connect", list_installer_updates: [update])
          end

          let(:url_helpers) { double("url_helpers", registration_url: smt_url) }

          before do
            allow(subject).to receive(:require).with("registration/sw_mgmt").and_return(true)
            allow(subject).to receive(:require).with("registration/url_helpers").and_return(true)
            allow(subject).to receive(:require).with("suse/connect").and_return(true)
            stub_const("Registration::SwMgmt", sw_mgmt)
            stub_const("Registration::UrlHelpers", url_helpers)
            stub_const("SUSE::Connect::YaST", suse_connect)
            allow(::FileUtils).to receive(:touch)
          end

          it "tries to update the installer using the given URL" do
            expect(sw_mgmt).to receive(:remote_product).with(base_product)
              .and_return(product)
            expect(manager).to receive(:add_repository).with(URI(update_url))
              .and_return(true)
            expect(suse_connect).to receive(:list_installer_updates).with(product, url: smt_url)
              .and_return([update])
            expect(subject.main).to eq(:restart_yast)
          end
        end

        context "in AutoYaST installation or upgrade" do
          let(:profile_url) { "http://ay.test.example.com/update" }

          before do
            expect(Yast::Mode).to receive(:auto).at_least(1).and_return(true)
            allow(Yast::Profile).to receive(:current)
              .and_return("general" => { "self_update_url" =>  profile_url })
            allow(::FileUtils).to receive(:touch)
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

  end

  describe "#update_installer" do
    let(:update_result) { true }
    let(:insecure) { "0" }

    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("Insecure").and_return(insecure)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return("1")
    end

    context "when update works" do
      it "returns true" do
        allow(manager).to receive(:add_repository).and_return([repo])
        allow(manager).to receive(:apply_all)
        expect(subject.update_installer).to eq(true)
      end
    end
  end
end

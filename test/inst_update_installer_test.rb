#!/usr/bin/env rspec

require_relative "test_helper"
require_relative "./support/fake_registration"
require "installation/clients/inst_update_installer"
require "singleton"

describe Yast::InstUpdateInstaller do

  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"
  Yast.import "GetInstArgs"
  Yast.import "UI"

  let(:manager) do
    double("update_manager", all_signed?: all_signed?, apply_all: true,
      repositories?: has_repos, repositories: repos)
  end
  let(:url) { "http://update.opensuse.org/\$arch/update.dud" }
  let(:real_url) { "http://update.opensuse.org/#{arch}/update.dud" }
  let(:remote_url) { true }
  let(:user_defined) { true }
  let(:update) { double("update", uri: URI(real_url), remote?: remote_url, user_defined?: user_defined) }
  let(:updates) { [update] }
  let(:arch) { "x86_64" }
  let(:all_signed?) { true }
  let(:network_running) { true }
  let(:has_repos) { true }
  let(:repo) { double("repo", repo_id: 42) }
  let(:repos) { [repo] }
  let(:restarting) { false }
  let(:profile) { {} }
  let(:ay_profile) { double("Yast::Profile", current: profile) }
  let(:ay_profile_location) { double("Yast::ProfileLocation") }
  let(:finder) { ::Installation::UpdateRepositoriesFinder.new }

  before do
    allow(::Installation::UpdateRepositoriesFinder).to receive(:new).and_return(finder)
    allow(Yast::GetInstArgs).to receive(:going_back).and_return(false)
    allow(Yast::NetworkService).to receive(:isNetworkRunning).and_return(network_running)
    allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
    allow(Yast::Installation).to receive(:restarting?).and_return(restarting)
    allow(Yast::Installation).to receive(:restart!) { :restart_yast }
    allow(finder).to receive(:updates).and_return(updates)
    allow(subject).to receive(:require).with("registration/url_helpers").and_raise(LoadError)
    stub_const("Registration::Storage::InstallationOptions", FakeInstallationOptions)
    stub_const("Registration::Storage::Config", FakeRegConfig)
    allow(Y2Packager::SelfUpdateAddonRepo).to receive(:copy_packages)

    # skip the libzypp initialization globally, enable in the specific tests
    allow(subject).to receive(:initialize_packager).and_return(true)
    allow(subject).to receive(:finish_packager)
    allow(subject).to receive(:fetch_profile).and_return(ay_profile)
    allow(subject).to receive(:process_profile)
    allow(subject).to receive(:valid_repositories?).and_return(true)
    allow(finder).to receive(:add_installation_repo)

    # stub the Profile module to avoid dependency on autoyast2-installation
    stub_const("Yast::Profile", ay_profile)
    stub_const("Yast::Language", double(language: "en_US"))

    FakeInstallationOptions.instance.custom_url = nil
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

    it "cleans up the package management at the end" do
      # override the global stub
      expect(subject).to receive(:finish_packager).and_call_original
      # pretend the package management has been initialized
      # TODO: test the uninitialized case as well
      subject.instance_variable_set(:@packager_initialized, true)

      expect(Yast::Pkg).to receive(:SourceGetCurrent).and_return([0])
      expect(Yast::Pkg).to receive(:SourceDelete).with(0)
      expect(Yast::Pkg).to receive(:SourceSaveAll)
      expect(Yast::Pkg).to receive(:SourceFinishAll)
      expect(Yast::Pkg).to receive(:TargetFinish)

      # just a shortcut to avoid mocking the whole update
      allow(subject).to receive(:disabled_in_linuxrc?).and_return(true)
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

    context "when some update is available" do
      let(:updates) { [update] }

      context "and update works" do
        before do
          allow(subject).to receive(:self_update_enabled?).and_return(true)
          allow(subject).to receive(:add_repository).and_return(true)
          allow(manager).to receive(:apply_all)
          allow(::FileUtils).to receive(:touch)
          allow(Y2Packager::SelfUpdateAddonRepo).to receive(:copy_packages)
        end

        it "creates update file and returns :restart_yast" do
          expect(subject.main).to eq(:restart_yast)
        end

        it "copies the add-on packages from the self-update repository" do
          expect(Y2Packager::SelfUpdateAddonRepo).to receive(:copy_packages)
            .with(repo.repo_id)
          subject.main
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

      context "when the update cannot be fetched from a user defined repository" do
        it "shows an error and returns :next" do
          expect(Yast::Popup).to receive(:Error)
          expect(manager).to receive(:add_repository)
            .and_raise(::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo)
          expect(subject.main).to eq(:next)
        end
      end

      context "when the update cannot be fetched from a default repository" do
        let(:user_defined) { false }

        it "does not show any error and returns :next" do
          expect(Yast::Popup).to_not receive(:Error)
          expect(manager).to receive(:add_repository)
            .and_raise(::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo)
          expect(subject.main).to eq(:next)
        end
      end

      context "when repository is empty" do
        let(:has_repos) { false }
        let(:repos) { [] }

        it "does not restart YaST" do
          expect(manager).to receive(:add_repository)
            .and_return(false)
          expect(subject.main).to eq(:next)
        end
      end

      context "when a default repository can't be probed" do
        let(:user_defined) { false }

        it "does not show any error and returns :next" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(manager).to receive(:add_repository)
            .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
          expect(subject.main).to eq(:next)
        end
      end

      context "when a user defined repository can't be probed" do
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
          let(:real_url) { "cd:/?device=sr0" }
          let(:remote_url) { false }

          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(manager).to receive(:add_repository)
              .and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
            expect(subject.main).to eq(:next)
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
      let(:data_file_exists) { false }
      let(:smt_url) { "https://smt.example.net" }
      let(:registration_libs) { true }

      before do
        allow(File).to receive(:exist?)
        allow(File).to receive(:exist?).with(/\/inst_update_installer.yaml\z/)
          .and_return(data_file_exists)
        allow(subject).to receive(:require_registration_libraries)
          .and_return(registration_libs)
        allow(File).to receive(:exist?).with(/installer_updated/).and_return(true)
        allow(Yast::Installation).to receive(:restart!)
      end

      context "and data file is available" do
        let(:data_file_exists) { true }

        it "sets custom_url" do
          allow(File).to receive(:read).and_return("---\ncustom_url: #{smt_url}\n")
          expect(FakeInstallationOptions.instance).to receive(:custom_url=)
            .with(smt_url)
          subject.main
        end
      end

      context "and data file is not available" do
        it "does not set custom_url" do
          expect(FakeInstallationOptions.instance).to_not receive(:custom_url=)
          subject.main
        end
      end

      context "and yast2-registration is not available" do
        let(:registration_libs) { false }
        let(:data_file_exists) { true }

        it "does not load custom_url" do
          expect(FakeInstallationOptions.instance).to_not receive(:custom_url=)
          subject.main
        end
      end

      it "finishes the restarting process" do
        expect(Yast::Installation).to receive(:finish_restarting!)
        subject.main
      end
    end
  end

  describe "#update_installer" do
    let(:update_result) { true }
    let(:insecure) { "0" }

    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("Insecure").and_return(insecure)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return(url)
    end

    context "when update works" do
      it "returns true" do
        allow(manager).to receive(:add_repository).and_return(true)
        allow(manager).to receive(:apply_all)
        expect(subject.update_installer).to eq(true)
      end
    end

    context "when update fails" do
      it "returns false" do
        allow(manager).to receive(:add_repository).and_return(false)
        expect(subject.update_installer).to eq(false)
      end
    end
  end
end

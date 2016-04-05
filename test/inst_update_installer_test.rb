#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"

describe Yast::InstUpdateInstaller do
  Yast.import "Arch"
  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"
  Yast.import "UI"

  let(:manager) { double("update_manager", all_signed?: all_signed?, apply_all: true) }
  let(:url) { "http://update.opensuse.org/\$arch/update.dud" }
  let(:real_url) { "http://update.opensuse.org/#{arch}/update.dud" }
  let(:arch) { "x86_64" }
  let(:all_signed?) { true }
  let(:network_running) { true }
  let(:repo) { double("repo") }

  before do
    allow(Yast::Arch).to receive(:architecture).and_return(arch)
    allow(Yast::NetworkService).to receive(:isNetworkRunning).and_return(network_running)
    allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
  end

  describe "#main" do
    context "when update is enabled" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return(url)
      end

      context "and update works" do
        before do
          allow(subject).to receive(:update_installer).and_return(true)
        end

        it "creates update file and returns :restart_yast" do
          expect(::FileUtils).to receive(:touch).twice
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

      context "when repository can't be probed" do
        context "and self-update URL is remote" do
          it "shows a dialog suggesting to check the network configuration" do
            expect(Yast::Popup).to receive(:YesNo).with(/problem reading/)
            expect(manager).to receive(:add_repository).and_raise(::Installation::UpdatesManager::CouldNotProbeRepo)
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
          expect(manager).to receive(:add_repository).with(URI(custom_url))
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

        it "gets URL from control file" do
          allow(::FileUtils).to receive(:touch)
          expect(manager).to receive(:add_repository).with(URI(real_url))
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

#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"

describe Yast::InstUpdateInstaller do
  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"
  Yast.import "UI"

  let(:manager) { double("update_manager", all_signed?: all_signed?, apply_all: true) }
  let(:url) { "http://update.opensuse.org/update.dud" }
  let(:all_signed?) { true }

  describe "#main" do
    context "when update is enabled" do
      before do
        allow(subject).to receive(:self_update_enabled?).and_return(true)
      end

      context "when update works" do
        before do
          allow(subject).to receive(:update_installer).and_return(true)
        end

        it "creates update file and returns :restart_yast" do
          expect(::FileUtils).to receive(:touch).twice
          allow(subject).to receive(:self_update_enabled?).and_return(true)
          expect(subject.main).to eq(:restart_yast)
        end
      end

      context "when update fails" do
        before do
          allow(subject).to receive(:update_installer).and_return(false)
        end

        it "does not create any file and returns :next" do
          expect(::FileUtils).to_not receive(:touch)
          expect(subject.main).to eq(:next)
        end
      end

      context "when an URL is specified through Linuxrc" do
        before do
          allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return(url)
          allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
        end

        it "tries to update the installer using the given URL" do
          expect(manager).to receive(:add_update).with(URI(url)).and_return(true)
          expect(manager).to receive(:apply_all).and_return(true)
          allow(::FileUtils).to receive(:touch)
          expect(subject.main).to eq(:restart_yast)
        end

        it "shows an error if update is not found" do
          expect(Yast::Popup).to receive(:Error)
          expect(manager).to receive(:add_update).with(URI(url)).and_return(false)
          expect(subject.main).to eq(:next)
        end
      end

      context "when no URL is specified through Linuxrc" do
        before do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return(url)
          allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
        end

        it "gets URL from control file" do
          allow(::FileUtils).to receive(:touch)
          expect(manager).to receive(:add_update).with(URI(url)).and_return(true)
          expect(subject.main).to eq(:restart_yast)
        end

        it "does not show an error if update is not found" do
          expect(Yast::Popup).to_not receive(:Error)
          expect(manager).to receive(:add_update).with(URI(url)).and_return(false)
          expect(subject.main).to eq(:next)
        end

        context "and control file doesn't have an URL" do
          let(:url) { "" }

          it "does not update the installer" do
            expect(subject).to_not receive(:update_installer)
          end
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
    let(:add_result) { true }
    let(:insecure) { "0" }

    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("Insecure").and_return(insecure)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return("1")
      allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
      allow(manager).to receive(:add_update).and_return(add_result)
    end

    context "when update works" do
      it "returns true" do
        allow(manager).to receive(:apply_all)
        expect(subject.update_installer).to eq(true)
      end
    end

    context "when applying an update fails" do
      it "raises an exception" do
        allow(manager).to receive(:apply_all).and_raise(StandardError)
        expect { subject.update_installer }.to raise_error(StandardError)
      end
    end

    context "when adding an update fails" do
      let(:add_result) { false }

      it "returns true" do
        expect(subject.update_installer).to eq(false)
      end
    end

    context "when signature is not OK" do
      let(:all_signed?) { false }

      context "when secure mode is disabled" do
        let(:insecure) { "1" }

        it "applies the update" do
          expect(manager).to receive(:apply_all)
          expect(subject.update_installer).to eq(true)
        end
      end

      context "when secure mode is enabled" do
        let(:insecure) { nil }

        it "does not apply the update if the user refuses" do
          expect(Yast::Popup).to receive(:AnyQuestion).and_return(false)
          expect(manager).to_not receive(:apply_all)
          expect(subject.update_installer).to eq(false)
        end

        it "applies the update if the user confirms" do
          expect(Yast::Popup).to receive(:AnyQuestion).and_return(true)
          expect(manager).to receive(:apply_all)
          expect(subject.update_installer).to eq(true)
        end
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"

describe Yast::InstUpdateInstaller do
  Yast.import "Linuxrc"
  Yast.import "ProductFeatures"

  let(:manager) { double("update_manager") }
  let(:url) { "http://update.opensuse.org/update.dud" }

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
        it "tries to update the installer using the given URL" do
          allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate").and_return(url)
          allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
          expect(manager).to receive(:add_update).with(URI(url))
          expect(subject.main).to eq(:next)
        end
      end

      context "when no URL is specified through Linuxrc" do

        it "gets URL from control file" do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return(url)
          allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
          expect(manager).to receive(:add_update).with(URI(url))
          expect(subject.main).to eq(:next)
        end

        context "and control file doesn't have an URL" do
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

    before do
      allow(::Installation::UpdatesManager).to receive(:new).and_return(manager)
      allow(manager).to receive(:add_update).and_return(add_result)
      allow(manager).to receive(:apply_all).and_return(update_result)
    end

    context "when update works" do
      let(:update_result) { true }

      it "returns true" do
        expect(subject.update_installer).to eq(true)
      end
    end

    context "when applying an update fails" do
      let(:update_result) { false }

      it "returns false" do
        expect(subject.update_installer).to eq(false)
      end
    end

    context "when adding an update fails" do
      let(:update_result) { true }
      let(:add_result) { false }

      it "returns true" do
        expect(subject.update_installer).to eq(false)
      end
    end
  end
end

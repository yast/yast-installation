#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_update_installer"

describe Yast::InstUpdateInstaller do
  let(:manager) { double("update_manager") }

  describe "#main" do
    before do
      allow(subject).to receive(:update_installer).and_return(update_result)
    end

    context "when update works" do
      let(:update_result) { true }

      it "creates update file and returns :restart_yast" do
        expect(::FileUtils).to receive(:touch)
        expect(::FileUtils).to receive(:touch)
        expect(subject.main).to eq(:restart_yast)
      end
    end

    context "when update fails" do
      let(:update_result) { false }

      it "does not create any file and returns :next" do
        expect(::FileUtils).to_not receive(:touch)
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

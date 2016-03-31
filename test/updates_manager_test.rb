#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/updates_manager"
require "installation/driver_update"
require "pathname"
require "uri"

describe Installation::UpdatesManager do
  subject(:manager) { Installation::UpdatesManager.new }

  let(:uri) { URI("http://updates.opensuse.org/sles12.dud") }

  let(:repo0) { double("repo0", apply: true) }
  let(:repo1) { double("repo1", apply: true) }
  let(:dud0)  { double("dud0", apply: true) }

  describe "#add_repository" do
    context "when repository is added successfully" do
      it "returns an array containing all repos" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_return(repo0)
        allow(repo0).to receive(:fetch)
        expect(manager.add_repository(uri)).to eq(:ok)
      end
    end

    context "when repository is not found" do
      it "returns :not_found" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_raise(Installation::UpdateRepository::ValidRepoNotFound)
        expect(manager.add_repository(uri)).to eq(:not_found)
      end
    end

    context "when repository can not be refreshed" do
      it "returns :error" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_raise(Installation::UpdateRepository::CouldNotRefreshRepo)
        expect(manager.add_repository(uri)).to eq(:error)
      end
    end

    context "when repository can not be probed" do
      it "returns :error" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_raise(Installation::UpdateRepository::CouldNotProbeRepo)
        expect(manager.add_repository(uri)).to eq(:error)
      end
    end
  end

  describe "#repositories" do
    context "when no update was added" do
      it "returns an empty array" do
        expect(manager.repositories).to be_empty
      end
    end

    context "when some update was added" do
      before do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_return(repo0)
        expect(repo0).to receive(:fetch).and_return(true)
        manager.add_repository(uri)
      end

      it "returns an array containing the updates" do
        expect(manager.repositories).to eq([repo0])
      end
    end
  end

  describe "#driver_updates" do
    context "when no driver updates exist" do
      before do
        allow(Installation::DriverUpdate).to receive(:find).and_return([])
      end

      it "returns an empty array" do
        expect(subject.driver_updates).to eq([])
      end
    end

    context "when some driver update exist" do
      before do
        allow(Installation::DriverUpdate).to receive(:find).and_return([dud0])
      end

      it "returns an array containing existing updates" do
        expect(subject.driver_updates).to eq([dud0])
      end
    end
  end

  describe "#apply_all" do
    before do
      allow(manager).to receive(:repositories).and_return([repo0, repo1])
    end

    it "applies all the updates" do
      expect(repo0).to receive(:apply)
      expect(repo1).to receive(:apply)
      manager.apply_all
    end

    context "when some driver update exists" do
      before do
        allow(manager).to receive(:driver_updates).and_return([dud0])
      end

      it "also re-applies the driver updates" do
        expect(dud0).to receive(:apply)
        manager.apply_all
      end
    end
  end
end

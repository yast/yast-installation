#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/updates_manager"
require "installation/driver_update"
require "pathname"
require "uri"

describe Installation::UpdatesManager do
  subject(:manager) { Installation::UpdatesManager.new }

  let(:uri) { URI("http://updates.opensuse.org/sles12") }

  let(:repo0) { double("repo0", apply: true, cleanup: true) }
  let(:repo1) { double("repo1", apply: true, cleanup: true) }
  let(:dud0)  { double("dud0", apply: true) }

  describe "#add_repository" do
    before do
      allow(Installation::UpdateRepository).to receive(:new).with(uri)
        .and_return(repo0)
    end

    context "when repository is added successfully" do
      it "returns an array containing all repos" do
        allow(repo0).to receive(:fetch)
        expect(manager.add_repository(uri)).to eq([repo0])
      end
    end

    context "when a valid repository is not found" do
      it "raises a NotValidRepo error" do
        allow(repo0).to receive(:fetch)
          .and_raise(Installation::UpdateRepository::NotValidRepo)
        expect { manager.add_repository(uri) }
          .to raise_error(Installation::UpdatesManager::NotValidRepo)
      end
    end

    context "when update could not be fetched" do
      it "raises a CouldNotFetchUpdateFromRepo error" do
        allow(repo0).to receive(:fetch)
          .and_raise(Installation::UpdateRepository::FetchError)
        expect { manager.add_repository(uri) }
          .to raise_error(Installation::UpdatesManager::CouldNotFetchUpdateFromRepo)
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
      expect(repo0).to receive(:cleanup)
      expect(repo1).to receive(:cleanup)
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

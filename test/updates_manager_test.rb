#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/updates_manager"
require "installation/driver_update"
require "pathname"
require "uri"

describe Installation::UpdatesManager do
  subject(:manager) { Installation::UpdatesManager.new }

  let(:uri) { URI("http://updates.opensuse.org/sles12.dud") }

  let(:repo0) { double("repo0") }
  let(:repo1) { double("repo1") }

  describe "#add_repository" do
    context "when repository is added successfully" do
      it "returns an array containing all repos" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_return(repo0)
        allow(repo0).to receive(:fetch)
        expect(manager.add_repository(uri)).to eq([repo0])
      end
    end

    context "when repository is not found" do
      it "returns false" do
        allow(Installation::UpdateRepository).to receive(:new).with(uri)
          .and_raise(Installation::UpdateRepository::NotFound)
        expect(manager.add_repository(uri)).to eq(false)
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

  describe "#apply_all" do
    it "applies all the updates" do
      allow(manager).to receive(:repositories).and_return([repo0, repo1])
      expect(repo0).to receive(:apply)
      expect(repo1).to receive(:apply)
      manager.apply_all
    end
  end
end

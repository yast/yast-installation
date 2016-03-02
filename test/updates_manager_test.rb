#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/updates_manager"
require "installation/driver_update"
require "pathname"
require "uri"

describe Installation::UpdatesManager do
  subject(:manager) { Installation::UpdatesManager.new(target) }

  let(:target) { Pathname.new("/update") }
  let(:uri) { URI("http://updates.opensuse.org/sles12.dud") }

  describe "#add_update" do
    it "adds a driver update to the list of updates" do
      expect(Installation::DriverUpdate).to receive(:new).with(uri)
      manager.add_update(uri)
    end
  end

  describe "#updates" do
    context "when no update was added" do
      it "returns an empty array" do
        expect(manager.updates).to be_empty
      end
    end

    context "when some update was added" do
      before do
        manager.add_update(uri)
      end

      it "returns an array containing the update" do
        updates = manager.updates
        expect(updates.size).to eq(1)
        update = updates.first
        expect(update.uri).to eq(uri)
      end
    end
  end

  describe "#fetch_all" do
    let(:update0) { double("update0") }
    let(:update1) { double("update1") }

    it "fetches all updates using consecutive numbers in the directory name" do
      allow(manager).to receive(:updates).and_return([update0, update1])
      expect(update0).to receive(:fetch).with(target.join("000"))
      expect(update1).to receive(:fetch).with(target.join("001"))
      manager.fetch_all
    end

    context "when some driver update exists" do
      before do
        allow(Pathname).to receive(:glob).with(target.join("*"))
          .and_return([Pathname.new("000")])
      end

      it "does not override the existing one" do
        allow(manager).to receive(:updates).and_return([update0])
        expect(update0).to receive(:fetch).with(target.join("001"))
        manager.fetch_all
      end
    end
  end

  describe "#apply_all" do
    let(:update0) { double("update0") }
    let(:update1) { double("update1") }

    it "applies all the updates" do
      allow(manager).to receive(:updates).and_return([update0, update1])
      expect(update0).to receive(:apply)
      expect(update1).to receive(:apply)
      manager.apply_all
    end
  end
end

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

  let(:update0) { double("update0") }
  let(:update1) { double("update1") }

  describe "#add_update" do
    before do
      allow(Installation::DriverUpdate).to receive(:new).with(uri)
        .and_return(update0)
    end

    it "fetchs the driver and it to the list of updates" do
      expect(update0).to receive(:fetch).with(target.join("000")).and_return(true)
      manager.add_update(uri)
      expect(manager.updates).to eq([update0])
    end

    context "if the update is not found" do
      before do
        allow(update0).to receive(:fetch).and_raise(Installation::DriverUpdate::NotFound)
      end

      it "returns false" do
        expect(manager.add_update(uri)).to eq(false)
      end

      it "does not add the update" do
        manager.add_update(uri)
        expect(manager.updates).to be_empty
      end
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
        allow(Installation::DriverUpdate).to receive(:new).with(uri)
          .and_return(update0)
        expect(update0).to receive(:fetch).with(target.join("000")).and_return(true)
        manager.add_update(uri)
      end

      it "returns an array containing the updates" do
        expect(manager.updates).to eq([update0])
      end
    end
  end

  describe "#fetch_all" do
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

  describe "#all_signed?" do
    let(:update0) { double("update0", signed?: true) }

    before do
      allow(manager).to receive(:updates).and_return([update0, update1])
    end

    context "when all updates are signed" do
      let(:update1) { double("update1", signed?: true) }

      it "returns true" do
        expect(manager).to be_all_signed
      end
    end

    context "when some update is not signed" do
      let(:update1) { double("update1", signed?: false) }

      it "returns false" do
        expect(manager).to_not be_all_signed
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/updates_manager"
require "installation/driver_update"
require "pathname"
require "uri"

describe Installation::UpdatesManager do
  subject(:manager) { Installation::UpdatesManager.new }

  let(:uri) { URI("http://updates.opensuse.org/sles12") }

  let(:repo0) { double("repo0", apply: true, cleanup: true, empty?: false) }
  let(:repo1) { double("repo1", apply: true, cleanup: true, empty?: false) }
  let(:dud0)  { double("dud0", apply: true) }

  describe "#add_repository" do
    before do
      allow(Installation::UpdateRepository).to receive(:new).with(uri)
        .and_return(repo0)
    end

    context "when repository is added successfully" do
      it "returns true and add the repository" do
        allow(repo0).to receive(:fetch)
        expect(manager.add_repository(uri)).to eq(true)
        expect(manager.repositories).to eq([repo0])
      end
    end

    context "when repository is empty" do
      it "returns false" do
        allow(repo0).to receive(:fetch)
        allow(repo0).to receive(:empty?).and_return(true)
        expect(manager.add_repository(uri)).to eq(false)
        expect(manager.repositories).to be_empty
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
    let(:new_control_file?) { false }

    before do
      allow(manager).to receive(:repositories).and_return([repo0, repo1])
      allow(File).to receive(:exist?).with("/usr/lib/skelcd/CD1/control.xml")
        .and_return(new_control_file?)
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

    context "when a new control file is available" do
      let(:new_control_file?) { true }

      it "updates the control file" do
        expect(Yast::Execute).to receive(:locally!)
          .with("/sbin/adddir", "/usr/lib/skelcd/CD1", "/")
        manager.apply_all
      end
    end

    it "does not replace the control file" do
      expect(Yast::Execute).to_not receive(:locally!)
        .with("/sbin/adddir", /skelcd/, "/")
      manager.apply_all
    end
  end

  describe "#repositories?" do
    context "when some repository was added" do
      before do
        allow(manager).to receive(:repositories).and_return([repo0])
      end

      it "returns true" do
        expect(manager.repositories?).to eq(true)
      end
    end

    context "when no repository was added" do
      before do
        allow(manager).to receive(:repositories).and_return([])
      end

      it "returns false" do
        expect(manager.repositories?).to eq(false)
      end
    end
  end
end

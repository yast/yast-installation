#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/driver_update"

Yast.import "Linuxrc"

describe Installation::DriverUpdate do
  subject(:update) { Installation::DriverUpdate.new(update_path) }

  let(:update_path) { FIXTURES_DIR.join("updates", "dud_000") }
  let(:losetup_content) do
    "NAME       SIZELIMIT OFFSET AUTOCLEAR RO BACK-FILE\n" \
    "/dev/loop5         0      0         0  0 /download/dud_000\n" \
    "/dev/loop6         0      0         0  0 #{FIXTURES_DIR.join("updates", "dud_002")}\n"
  end

  before do
    allow(Yast::SCR).to receive(:Execute)
      .with(Yast::Path.new(".target.bash_output"), "/sbin/losetup")
      .and_return("exit" => 0, "stdout" => losetup_content)
    allow(Yast::SCR).to receive(:Read)
      .with(Yast::Path.new(".proc.mounts"))
      .and_return(["spec" => "/dev/loop6", "file" => "/mounts/mp_0005"])
  end

  describe ".find" do
    context "when no updates exist" do
      it "returns an empty array" do
        expect(described_class.find([FIXTURES_DIR])).to eq([])
      end
    end

    context "when updates exist" do
      it "returns an array of driver updates" do
        updates = described_class.find([FIXTURES_DIR.join("updates")])
        expect(updates).to all(be_an(described_class))
        expect(updates.size).to eq(3)
      end
    end
  end

  describe ".new" do
    context "when file does not exist" do
      let(:update_path) { Pathname.pwd.join("dud_001") }

      it "raises a NotFound exception" do
        expect { update }.to raise_error(::Installation::DriverUpdate::NotFound)
      end
    end
  end

  describe "#kind" do
    context "when is a driver update disk" do
      let(:update_path) { FIXTURES_DIR.join("updates", "dud_000") }

      it "returns :dud" do
        expect(update.kind).to eq(:dud)
      end
    end

    context "when is an archive" do
      let(:update_path) { FIXTURES_DIR.join("updates", "dud_002") }

      it "returns :archive" do
        expect(update.kind).to eq(:archive)
      end
    end
  end

  describe "#path" do
    it "returns the path where the DUD is located" do
      expect(update.path).to eq(update_path)
    end
  end

  describe "#apply" do
    before do
      allow(update).to receive(:instsys_path)
        .and_return(instsys_path)
    end

    context "when instsys_path exists" do
      let(:instsys_path) do
        double("instsys", :exist? => true, :to_s => "/some-path")
      end

      it "applies the driver update" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), "/etc/adddir #{update.instsys_path} /")
          .and_return("exit" => 0, "stdout" => "", "stderr" => "")
        update.apply
      end
    end

    context "when instsys_path does not exist" do
      let(:instsys_path) { double("instsys", :exist? => false) }

      it "returns false" do
        expect(Yast::SCR).to_not receive(:Execute)
        expect(update.apply).to eq(false)
      end
    end

    context "when instsys_path cannot be determined" do
      let(:instsys_path) { nil }

      it "returns false" do
        expect(Yast::SCR).to_not receive(:Execute)
        expect(update.apply).to eq(false)
      end
    end
  end
end

#!/usr/bin/env rspec

require_relative "./test_helper"

require "installation/driver_update"
require "uri"

Yast.import "Linuxrc"

describe Installation::DriverUpdate do
  FIXTURES_DIR = Pathname.new(__FILE__).dirname.join("fixtures")

  subject(:dud) { Installation::DriverUpdate.new(update_path) }
  let(:update_path) { FIXTURES_DIR.join("updates", "000") }

  describe ".find" do
    context "when no updates exist" do
      it "returns an empty array" do
        expect(described_class.find(FIXTURES_DIR)).to eq([])
      end
    end

    context "when updates exist" do
      it "returns an array of driver updates" do
        updates = described_class.find(FIXTURES_DIR.join("updates"))
        expect(updates).to all(be_an(described_class))
      end
    end
  end

  describe "#path" do
    it "returns the path where the DUD is located" do
      expect(dud.path).to eq(update_path)
    end
  end

  describe "#apply" do
    context "when the remote file was fetched" do
      it "applies the DUD and executes update.pre script" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), "/etc/adddir #{update_path}/inst-sys /")
          .and_return("exit" => 0, "stdout" => "", "stderr" => "")
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), "#{update_path}/install/update.pre")
          .and_return("exit" => 0, "stdout" => "", "stderr" => "")
        dud.apply
      end

      context "if an update.pre does not exist" do
        let(:update_path) { FIXTURES_DIR.join("updates", "001") }

        it "does not try to run the update.pre script" do
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash_output"), /adddir/)
            .and_return("exit" => 0)
          expect(Yast::SCR).to_not receive(:Execute)
            .with(Yast::Path.new(".target.bash_output"), "update.pre")
          dud.apply
        end
      end
    end
  end
end

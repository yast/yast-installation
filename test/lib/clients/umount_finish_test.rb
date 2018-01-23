#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/umount_finish"

Yast.import "ProductFeatures"

describe Yast::UmountFinishClient do
  subject(:client) { described_class.new }

  describe "root_subvol_read_only_configured?" do
    before do
      Yast::ProductFeatures.Import(features)
    end

    after do
      # Reset the product features to its default values after
      # fiddling with then
      Yast::ProductFeatures.Import({})
    end

    context "if there is no /partitioning section in the product features" do
      let(:features) { {} }

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end

    context "if there is no /partitioning/proposal section in the product features" do
      let(:features) { { "partitioning" => {} } }

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end

    context "if root_subvolume_read_only is not set in /partitioning/proposal" do
      let(:features) do
        { "partitioning" => { "proposal" => {} } }
      end

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end

    context "if root_subvolume_read_only is set directly in the /partitioning section" do
      let(:features) do
        { "partitioning" => { "root_subvolume_read_only" => true } }
      end

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end

    context "if root_subvolume_read_only is set to true in the /partitioning/proposal section" do
      let(:features) do
        {
          "partitioning" => {
            "proposal" => { "root_subvolume_read_only" => true }
          }
        }
      end

      it "returns true" do
        expect(client.root_subvol_read_only_configured?).to eq true
      end
    end

    context "if root_subvolume_read_only is set to false in /partitioning/proposal section" do
      let(:features) do
        {
          "partitioning" => {
            "proposal" => { "root_subvolume_read_only" => false }
          }
        }
      end

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end

    # Validation should protect us from this, but is not always checked
    context "if root_subvolume_read_only has a non boolean value in /partitioning/proposal section" do
      let(:features) do
        {
          "partitioning" => {
            "proposal" => { "root_subvolume_read_only" => "not so sure" }
          }
        }
      end

      it "returns false" do
        expect(client.root_subvol_read_only_configured?).to eq false
      end
    end
  end
end

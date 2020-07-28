#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/deploy_image_auto"

Yast.import "Installation"

describe Yast::DeployImageAutoClient do
  subject(:client) { Yast::DeployImageAutoClient.new }

  describe "#export" do
    context "image deployment is disabled" do
      it "return empty hash" do
        allow(Yast::Installation).to receive(:image_installation).and_return(false)

        expect(subject.export).to eq({})
      end
    end

    context "image deployment is enabled" do
      it "return hash with image_installation" do
        allow(Yast::Installation).to receive(:image_installation).and_return(true)

        expect(subject.export).to eq("image_installation" => true)
      end
    end
  end

  describe "#import" do
    let(:profile) { { "image_installation" => true } }

    it "imports the profile" do
      client.import(profile)
      expect(Yast::Installation.image_installation).to eq(true)
      expect(Yast::ImageInstallation.changed_by_user).to eq(true)
    end
  end

  describe "#summary" do
    before do
      Yast::Installation.image_installation = true
    end

    it "returns the AutoYaST summary" do
      expect(client.summary).to match(/enabled/)
    end
  end

  describe "#modified?" do
    it "settings are modified ?" do
      client.modified
      expect(client.modified?).to eq(true)
    end
  end

  describe "#reset" do
    it "resets settings" do
      expect(Yast::ImageInstallation).to receive(:FreeInternalVariables)
      client.reset
      expect(Yast::Installation.image_installation).to eq(false)
    end
  end

  describe "#write" do
    context "image installation enabled" do
      it "writes keyboard information" do
        expect(Yast::WFM).to receive(:call).with("inst_prepare_image")
        Yast::Installation.image_installation = true

        client.write
      end
    end
  end

end

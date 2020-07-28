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

end

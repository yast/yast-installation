#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/deploy_image_auto"

Yast.import "Installation"

describe Yast::DeployImageAutoClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:Args) do |*params|
        if params.empty?
          args
        else
          args[params.first]
        end
      end
    end

    context "Export argument passed" do
      let(:args) { ["Export"] }

      it "return empty hash if image deployment is disabled" do
        allow(Yast::Installation).to receive(:image_installation).and_return(false)

        expect(subject.main).to eq({})
      end

      it "return hash with image_installation if image deployment is enabled" do
        allow(Yast::Installation).to receive(:image_installation).and_return(true)

        expect(subject.main).to eq("image_installation" => true)
      end
    end
  end
end

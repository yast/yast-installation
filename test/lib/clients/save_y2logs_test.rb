#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/save_y2logs"

Yast.import "ProductFeatures"

describe Yast::SaveY2logs do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:bash_path) { Yast::Path.new(".local.bash") }
    
    context "globals/save_y2logs in control.xml is false" do
      it "does not save y2logs" do
        expect(Yast::ProductFeatures).to receive(:GetBooleanFeature).with("globals", "save_y2logs").and_return(false)
        expect(Yast::WFM).not_to receive(:Execute).with(
                                   bash_path,
                                   "/usr/sbin/save_y2logs '/var/log/YaST2/yast-installation-logs.tar.xz'")
        client.main
      end
    end

    context "globals/save_y2logs in control.xml is true" do
      it "saves y2logs" do
        expect(Yast::ProductFeatures).to receive(:GetBooleanFeature).with("globals", "save_y2logs").and_return(true)
        expect(Yast::WFM).to receive(:Execute).with(
                               bash_path,
                               "/usr/sbin/save_y2logs '/var/log/YaST2/yast-installation-logs.tar.xz'")
        client.main
      end
    end
  end
end

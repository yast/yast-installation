#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/services"

describe ::Installation::Services do
  before do
    # simulate non used class
    described_class.instance_variable_set(:@enabled, nil)
  end

  describe ".enabled" do
    it "returns list of previously set services" do
      described_class.enabled = ["test"]
      expect(described_class.enabled).to eq ["test"]
    end

    it "returns empty list if not set previously" do
      expect(described_class.enabled).to eq []
    end
  end

  describe ".enabled=" do
    it "sets list of services to enable" do
      described_class.enabled = ["test"]
      expect(described_class.enabled).to eq ["test"]
    end

    it "raise exception if non-array is passed" do
      expect { described_class.enabled = "test" }.to raise_error(ArgumentError)
    end
  end

  describe ".write" do
    it "enables all services previously set" do
      described_class.enabled = ["test"]
      service = double(enable: true)
      expect(Yast::SystemdService).to receive(:find!).with("test").and_return(service)
      expect(service).to receive(:enable)

      described_class.write
    end

    it "raises Yast::SystemdServiceNotFound exception if service to enable does not exist" do
      described_class.enabled = ["non-existing-service"]

      expect{described_class.write}.to raise_error(Yast::SystemdServiceNotFound)
    end
  end
end

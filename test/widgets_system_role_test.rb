#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/widgets/system_role"

describe ::Installation::Widgets::ControllerNode do
  it "has label" do
    expect(subject.label).to_not be_empty
  end

  context "initialization" do
    it "is initialized with the previously stored value if present" do
      allow(described_class).to receive(:location).and_return("previous_location")
      expect(subject).to receive(:value=).with("previous_location")

      subject.init
    end
  end

  context "store" do
    it "stores current value" do
      expect(subject).to receive(:value).and_return("value_to_store")

      expect(described_class).to receive(:location=).with("value_to_store")

      subject.store
    end
  end

  context "validation" do
    it "reports an error if the current value is not a valid IP or FQDN and returns false" do
      allow(Yast::IP).to receive(:Check).and_return(false)
      allow(Yast::Hostname).to receive(:CheckFQ).and_return(false)
      expect(Yast::Popup).to receive(:Error)

      expect(subject.validate).to eql(false)
    end

    it "returns true if the current value is a valid IP" do
      allow(Yast::IP).to receive(:Check).and_return(true)
      allow(Yast::Hostname).to receive(:CheckFQ).and_return(false)

      expect(subject.validate).to eql(true)
    end

    it "returns true if the current value is a valid FQDN" do
      allow(Yast::IP).to receive(:Check).and_return(false)
      allow(Yast::Hostname).to receive(:CheckFQ).and_return(true)

      expect(subject.validate).to eql(true)
    end
  end

end

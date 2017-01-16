#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/clients/services_finish"

describe ::Installation::Clients::ServicesFinish do
  describe "#title" do
    it "returns string with title" do
      expect(subject.title).to be_a ::String
    end
  end

  describe "#write" do
    it "writes installation services" do
      expect(::Installation::Services).to receive(:write)

      subject.write
    end
  end
end

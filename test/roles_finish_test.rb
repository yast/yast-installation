#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/clients/roles_finish"
require "fileutils"

describe ::Installation::Clients::RolesFinish do
  describe "#title" do
    it "returns string with title" do
      expect(subject.title).to be_a ::String
    end
  end

  describe "#write" do
    it "calls finish handler for the current role" do
      expect(::Installation::SystemRole).to receive(:finish)

      subject.write
    end
  end
end

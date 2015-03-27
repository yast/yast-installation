#! /usr/bin/env rspec

require_relative "./test_helper"
require_relative "../src/include/installation/misc"

# a testing class for includign the "misc" include
class InstallationMiscIncludeTest
  include Yast::InstallationMiscInclude
end

# fake AutoinstConfig to avoid dependency on autoyast
class Yast::AutoinstConfig
end

# we need to mock these modules
Yast.import "Stage"
Yast.import "Mode"
Yast.import "ProductControl"

def stub_initialstage(bool)
  allow(Yast::Stage).to receive(:initial).and_return(bool)
end

def stub_autoinst(bool)
  allow(Yast::Mode).to receive(:autoinst).and_return(bool)
end

def stub_autoupgrade(bool)
  allow(Yast::Mode).to receive(:autoupgrade).and_return(bool)
end

def stub_secondstage(bool)
  allow(Yast::AutoinstConfig).to receive(:second_stage).and_return(bool)
end

describe Yast::InstallationMiscInclude do
  subject { InstallationMiscIncludeTest.new }
  describe "#second_stage_required?" do
    before { allow(Yast::ProductControl).to receive(:RunRequired).and_return(true) }

    it "returns false when in initial stage" do
      stub_initialstage(false)
      expect(subject.second_stage_required?).to eq false
    end

    context "when in autoinst mode" do
      before do
        stub_autoinst(true)
        stub_autoupgrade(false)
        stub_initialstage(true)
      end

      it "returns true when second stage is defined in autoinst configuration" do
        stub_secondstage(true)
        expect(subject.second_stage_required?).to eq true
      end

      it "returns false when second stage is not defined in autoinst configuration" do
        stub_secondstage(false)
        expect(subject.second_stage_required?).to eq false
      end
    end

    context "when in autoupgrade mode" do
      before do
        stub_autoinst(false)
        stub_autoupgrade(true)
        stub_initialstage(true)
      end

      it "returns true when second stage is defined in autoinst configuration" do
        stub_secondstage(true)
        expect(subject.second_stage_required?).to eq true
      end

      it "returns false when second stage is not defined in autoinst configuration" do
        stub_secondstage(false)
        expect(subject.second_stage_required?).to eq false
      end
    end

    context "when in neiter in autoinst nor in autoupgrade mode" do
      before do
        stub_autoinst(false)
        stub_autoupgrade(false)
        stub_initialstage(true)
      end

      it "returns true when second stage is defined in autoinst configuration" do
        stub_secondstage(true)
        expect(subject.second_stage_required?).to eq true
      end

      it "returns true when second stage is not defined in autoinst configuration" do
        stub_secondstage(false)
        expect(subject.second_stage_required?).to eq true
      end
    end
  end
end

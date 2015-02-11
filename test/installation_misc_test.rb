#! /usr/bin/env rspec

require_relative "./test_helper"

require_relative "../src/include/installation/misc"


# a testing class for includign the "misc" include
class InstallationMiscIncludeTest
  include Yast::InstallationMiscInclude
end

# we need to mock these modules
Yast.import "Stage"

describe Yast::InstallationMiscInclude do
  subject { InstallationMiscIncludeTest.new }

  describe "#SecondStageRequired?" do
    it "returns nil if not running in the first stage" do
      expect(Yast::Stage).to receive(:initial).and_return(false)
      
      expect(subject.SecondStageRequired?).to eq(nil)
    end
  end
end

#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_errors"

describe ::Installation::ProposalErrors do
  describe "#approved?" do
    it "returns true if there is no error stored" do
      expect(Yast::Popup).to_not receive(:ErrorAnyQuestion)
      expect(subject.approved?).to eq true
    end

    it "asks user to approve errors and returns true if approved" do
      subject.append("test")

      expect(Yast::Popup).to receive(:ErrorAnyQuestion).and_return(false)
      expect(subject.approved?).to eq true

      expect(Yast::Popup).to receive(:ErrorAnyQuestion).and_return(true)
      expect(subject.approved?).to eq false
    end

    it "in autoyast ask with timeout and return true if timeout exceed" do
      subject.append("test")
      allow(Yast::Mode).to receive(:auto).and_return(true)

      # timed error return false when timeout exceed
      expect(Yast::Popup).to receive(:TimedErrorAnyQuestion).and_return(false)
      expect(subject.approved?).to eq true
    end
  end
end

#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_runner"

describe ::Installation::ProposalRunner do
  describe "#run" do

    it "do nothing if run non-interactive" do
      Yast.import "AutoinstConfig"
      Yast.import "Mode"
      allow(Yast::AutoinstConfig).to receive(:Confirm).and_return(false)
      allow(Yast::Mode).to receive(:autoinst).and_return(true)

      expect(subject.run).to eq :auto
    end

    it "do nothing if given proposal type is disabled" do
      Yast.import "ProductControl"
      Yast.import "GetInstArgs"
      allow(Yast::ProductControl).to receive(:GetDisabledProposals).and_return(["initial"])
      allow(Yast::GetInstArgs).to receive(:proposal).and_return("initial")

      expect(subject.run).to eq :auto
    end

    it "runs" do
      # TODO: just catch exceptions
      expect(subject.run).to eq :abort
    end
  end
end

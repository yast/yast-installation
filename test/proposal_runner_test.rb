#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_runner"

describe ::Installation::ProposalRunner do
  before do
    # mock constant to avoid dependency on autoyast
    autoinst_config = double(Confirm: false)
    stub_const("Yast::AutoinstConfig", autoinst_config)
  end

  describe "#run" do
    it "do nothing if run non-interactive" do
      Yast.import "Mode"
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

    it "passes a moske test" do
      expect { subject.run }.to_not raise_error
    end
  end
end

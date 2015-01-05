#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_store"

Yast.import "ProductControl"

describe ::Installation::ProposalStore do

  subject { ::Installation::ProposalStore.new "initial" }

  def mock_properties(data={})
    allow(Yast::ProductControl).to receive(:getProposalProperties)
      .and_return(data)
  end

  describe "#headline" do
    it "use translated label from product control" do
      original_label = "Label"
      translated_label = "Translated label"
      mock_properties("label" => original_label)

      allow(Yast::ProductControl).to receive(:getProposalTextDomain)
        .and_return("my_textdomain")

      expect(Yast::Builtins).to receive(:dgettext)
        .with("my_textdomain", original_label)
        .and_return(translated_label)

      expect(subject.headline).to eq(translated_label)
    end

    it "return translated default if missing in product control" do
      mock_properties

      expect(subject.headline).to eq("Installation Overview")
    end
  end

  describe "#has_tabs?" do
    it "returns true if proposal contains tabs" do
      mock_properties("proposal_tabs" => [])

      expect(subject.has_tabs?).to eq(true)
    end
  end

  describe "#can_be_skipped?" do
    it "use value from properties if set" do
      mock_properties("enable_skip" => "false")

      expect(subject.can_be_skipped?).to eq(false)
    end

    it "use default based on proposal mode" do
      expect(subject.can_be_skipped?).to eq(false)
      network_proposal = ::Installation::ProposalStore.new("network")
      expect(network_proposal.can_be_skipped?).to eq(true)
    end
  end
end

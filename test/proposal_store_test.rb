#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_store"

Yast.import "ProductControl"

describe ::Installation::ProposalStore do
  subject { ::Installation::ProposalStore.new "initial" }

  def mock_properties(data = {})
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

  describe "#tabs?" do
    it "returns true if proposal contains tabs" do
      mock_properties("proposal_tabs" => [])

      expect(subject.tabs?).to eq(true)
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

  describe "tab_labels" do
    it "returns list of labels for each tab" do
      mock_properties("proposal_tabs" => [
        {
          "label" => "tab1"
        },
        {
          "label" => "tab2"
        }
      ])

      expect(subject.tab_labels).to include("tab1")
      expect(subject.tab_labels).to include("tab2")
    end

    it "raises exception if used on non-tab proposal" do
      mock_properties

      expect { subject.tab_labels }.to raise_error
    end
  end

  describe "#help_text" do
    it "returns string with localized help" do
      expect(subject.help_text).to be_a String
    end
  end

  describe "#proposal_names" do
    it "returns array with string names of clients" do
      allow(Yast::ProductControl).to receive(:getProposals)
        .and_return([
          ["test1"],
          ["test2"],
          ["test3"]
        ])

      expect(subject.proposal_names).to include("test1")
      expect(subject.proposal_names).to include("test2")
      expect(subject.proposal_names).to include("test3")
    end

    it "use same order as in control file to preserve evaluation order" do
      allow(Yast::ProductControl).to receive(:getProposals)
        .and_return([
          ["test1"],
          ["test2"],
          ["test3"]
        ])

      expect(subject.proposal_names).to eq(["test1", "test2", "test3"])
    end
  end

  describe "#presentation_order" do
    context "proposal without tabs" do
      it "returns array with string names of client in presentation order" do
        allow(Yast::ProductControl).to receive(:getProposals)
          .and_return([
            ["test1", 90],
            ["test2", 30],
            ["test3", 50]
          ])

        expect(subject.presentation_order).to eq(["test2", "test3", "test1"])
      end

      it "replace value for missing presentation order with 50" do
        allow(Yast::ProductControl).to receive(:getProposals)
          .and_return([
            ["test1", 90],
            ["test2"],
            ["test3", 40]
          ])

        expect(subject.presentation_order).to eq(["test3", "test2", "test1"])
      end
    end

    context "proposal with tabs" do
      it "returns array of arrays with order in each tab" do
        mock_properties("proposal_tabs" => [
          {
            "proposal_modules" => [
              "tab1_client1",
              "tab1_client2"
            ]
          },
          {
            "proposal_modules" => [
              "tab2_client1",
              "tab2_client2",
              "tab2_client3"
            ]
          }
        ])

        expect(subject.presentation_order.size).to eq 2
        expect(subject.presentation_order[0].size).to eq 2
        expect(subject.presentation_order[1].size).to eq 3
      end

      it "adds '_proposal' suffix to clients if missing" do
        mock_properties("proposal_tabs" => [
          {
            "proposal_modules" => [
              "tab1_client1",
              "tab1_client2"
            ]
          },
          {
            "proposal_modules" => [
              "tab2_client1",
              "tab2_client2",
              "tab2_client3"
            ]
          }
        ])

        expect(subject.presentation_order[0]).to include "tab1_client1_proposal"
        expect(subject.presentation_order[1]).to include "tab2_client1_proposal"
      end
    end
  end
end

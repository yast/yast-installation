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
    before do
      allow(Yast::WFM).to receive(:ClientExists).and_return(true)
    end

    it "returns array with string names of clients" do
      allow(Yast::WFM).to receive(:ClientExists).with(/test3/).and_return(false)

      allow(Yast::ProductControl).to receive(:getProposals)
        .and_return([
          ["test1"],
          ["test2"],
          ["test3"]
        ])

      expect(subject.proposal_names).to include("test1")
      expect(subject.proposal_names).to include("test2")
      expect(subject.proposal_names).not_to include("test3")
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

  let(:client_description) {{
    "rich_text_title" => "Software",
    "menu_title"      => "&Software",
    "id"              => "software",
    "links"           => [ "software_link_1", "software_link_2" ]
  }}

  let(:client_name) { "software_proposal" }

  describe "#description_for" do
    it "returns description for a given client" do
      expect(Yast::WFM).to receive(:CallFunction).with(client_name, ["Description", {}]).and_return(client_description).once

      desc1 = subject.description_for(client_name)
      # description should be cached
      desc2 = subject.description_for(client_name)

      expect(desc1["id"]).to eq("software")
      expect(desc2["id"]).to eq("software")
    end
  end

  describe "#id_for" do
    it "returns id for a given client" do
      allow(subject).to receive(:description_for).with(client_name).and_return(client_description)

      expect(subject.id_for(client_name)).to eq(client_description["id"])
    end
  end

  describe "#title_for" do
    it "returns title for a given client" do
      allow(subject).to receive(:description_for).with(client_name).and_return(client_description)

      expect(subject.title_for(client_name)).to eq(client_description["rich_text_title"])
    end
  end

  describe "#handle_link" do
    before do
      allow(Yast::WFM).to receive(:CallFunction).with(client_name, ["Description", {}]).and_return(client_description)
    end

    context "when client('Description') has not been called before" do
      it "raises an exception" do
        expect { subject.handle_link("software") }.to raise_error /no client descriptions known/
      end
    end

    context "when no client matches the given link" do
      it "raises an exception" do
        # Cache some desriptipn first
        subject.description_for(client_name)

        expect { subject.handle_link("unknown_link") }.to raise_error /Unknown user request/
      end
    end

    context "when client('Description') has been called before" do
      it "calls a given client and returns its result" do
        # Description needs to be cached first
        subject.description_for(client_name)

        expect(Yast::WFM).to receive(:CallFunction).with(client_name,
          ["AskUser", {"has_next"=>false, "chosen_id"=>"software"}]).and_return(:next)
        expect(subject.handle_link("software")).to eq(:next)
      end
    end
  end
end

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

  let(:proposal_names) { ["proposal_a", "proposal_b", "proposal_c"] }

  let(:proposal_a) {{
    "rich_text_title" => "Proposal A",
    "menu_title"      => "&Proposal A",
    "id"              => "proposal_a",
    "links"           => [ "proposal_a-link_1", "proposal_a-link_2" ]
  }}

  let(:proposal_a_expected_val) { 3 }

  let(:proposal_a_with_trigger) {{
    "rich_text_title" => "Proposal A",
    "menu_title"      => "&Proposal A",
    "id"              => "proposal_a",
    "trigger"         => {
      "expect"        => "Yast::ProductControl.proposal_a_val",
      "value"         => proposal_a_expected_val,
    }
  }}

  let(:proposal_b) {{
    "rich_text_title" => "Proposal B",
    "menu_title"      => "&Proposal B",
    "id"              => "proposal_b"
  }}

  let(:proposal_b_with_language_change) {{
    "rich_text_title"  => "Proposal B",
    "menu_title"       => "&Proposal B",
    "id"               => "proposal_b",
    "language_changed" => true
  }}

  let(:proposal_b_with_fatal_error) {{
    "rich_text_title" => "Proposal B",
    "menu_title"      => "&Proposal B",
    "id"              => "proposal_b",
    "warning_level"   => :fatal,
    "warning"         => "some fatal error"
  }}

  let(:proposal_c) {{
    "rich_text_title" => "Proposal C",
    "menu_title"      => "&Proposal C"
  }}

  let(:proposal_c_expected_val) { true }

  let(:proposal_c_with_trigger) {{
    "rich_text_title" => "Proposal C",
    "menu_title"      => "&Proposal C",
    "trigger"         => {
      "expect"        => "
        # multi-line with coments
        1 + 1 + 1 + 1 + 1
        Yast::ProductControl.proposal_c_val
      ",
      "value"         => proposal_c_expected_val,
    }
  }}

  let(:proposal_c_with_incorrect_trigger) {{
    "rich_text_title" => "Proposal C",
    "menu_title"      => "&Proposal C",
    "trigger"         => {
      # 'expect' must be a string that is evaluated later
      "expect"        => 333,
      "value"         => "anything",
    }
  }}

  let(:proposal_c_with_exception) {{
    "rich_text_title" => "Proposal C",
    "menu_title"      => "&Proposal C",
    "trigger"         => {
      # 'expect' must be a string that is evaluated later
      "expect"        => "
        test2 = nil
        test2.first
      ",
      "value"         => 22,
    }
  }}

  describe "#make_proposals" do
    before do
      allow(subject).to receive(:proposal_names).and_return(proposal_names)
      allow(Yast::WFM).to receive(:CallFunction).with("proposal_a", anything()).and_return(proposal_a)
      allow(Yast::WFM).to receive(:CallFunction).with("proposal_b", anything()).and_return(proposal_b)
      allow(Yast::WFM).to receive(:CallFunction).with("proposal_c", anything()).and_return(proposal_c)
    end

    context "when all proposals return correct data" do
      it "for each proposal client, calls given callback and creates new proposal" do
        @callback = 0
        callback = Proc.new { @callback += 1 }

        expect{ subject.make_proposals(callback: callback) }.not_to raise_exception
        expect(@callback).to eq(proposal_names.size)
      end
    end

    context "when some proposal returns invalid data (e.g. crashes)" do
      it "raises an exception" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_b", anything()).and_return(nil)

        expect { subject.make_proposals }.to raise_exception /Invalid proposal from client/
      end
    end

    context "when given callback is not a block" do
      it "raises an exception" do
        expect { subject.make_proposals(callback: 4) }.to raise_exception /Callback is not a block/
      end
    end

    context "when returned proposal contains a 'trigger' section" do
      it "for each proposal client, creates new proposal and calls the client while trigger evaluates to true" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_a", anything()).and_return(proposal_a_with_trigger)
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_c", anything()).and_return(proposal_c_with_trigger)

        # Proposal A wants to be additionally called twice
        allow(Yast::ProductControl).to receive(:proposal_a_val).and_return(0, 0, proposal_a_expected_val)
        # Proposal C wants to be additionally called once
        allow(Yast::ProductControl).to receive(:proposal_c_val).and_return(false, proposal_c_expected_val)

        expect(subject).to receive(:make_proposal).with("proposal_a", anything()).exactly(3).times.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_b", anything()).exactly(1).times.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_c", anything()).exactly(2).times.and_call_original

        subject.make_proposals
      end
    end

    context "when returned proposal triggers changing a language" do
      it "calls all proposals again with language_changed: true" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_b", anything()).and_return(proposal_b_with_language_change, proposal_b)

        # Call proposals till the one that changes the language
        expect(subject).to receive(:make_proposal).with("proposal_a", hash_including(:language_changed => false)).once.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_b", hash_including(:language_changed => false)).once.and_call_original

        # Call all again with language_changed: true
        expect(subject).to receive(:make_proposal).with("proposal_a", hash_including(:language_changed => true)).once.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_b", hash_including(:language_changed => true)).once.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_c", hash_including(:language_changed => true)).once.and_call_original

        subject.make_proposals
      end
    end

    context "when returned proposal contains a fatal error" do
      it "calls all proposals till fatal error is received, then it stops proceeding immediately" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_b", anything()).and_return(proposal_b_with_fatal_error)

        expect(subject).to receive(:make_proposal).with("proposal_a", anything()).once.and_call_original
        expect(subject).to receive(:make_proposal).with("proposal_b", anything()).once.and_call_original
        # Proposal C is never called, as it goes after proposal B
        expect(subject).not_to receive(:make_proposal).with("proposal_c", anything())

        subject.make_proposals
      end
    end

    context "when trigger from proposal is incorrectly set" do
      it "raises an exception" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_c", anything()).and_return(proposal_c_with_incorrect_trigger)

        expect { subject.make_proposals }.to raise_error /Incorrect definition/
      end
    end

    context "when trigger from proposal raises an exception" do
      it "raises an exception" do
        allow(Yast::WFM).to receive(:CallFunction).with("proposal_c", anything()).and_return(proposal_c_with_exception)

        expect { subject.make_proposals }.to raise_error /Checking the trigger expectations for proposal_c have failed/
      end
    end

    context "When any proposal client wants to retrigger its run more than MAX_LOOPS_IN_PROPOSAL times" do
      it "stops iterating over proposals immediately" do
        allow(subject).to receive(:should_be_called_again?).with(/proposal_(a|b)/).and_return(false)
        # Proposal C wants to be called again and again
        allow(subject).to receive(:should_be_called_again?).with("proposal_c").and_return(true)

        expect(subject).to receive(:make_proposal).with(/proposal_(a|b)/, anything()).twice.and_call_original
        # Number of calls including the initial one
        expect(subject).to receive(:make_proposal).with("proposal_c", anything()).exactly(8).times.and_call_original

        subject.make_proposals
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

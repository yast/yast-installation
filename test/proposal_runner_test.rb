#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_runner"

Yast.import "ProductControl"
Yast.import "GetInstArgs"
Yast.import "Mode"

describe ::Installation::ProposalRunner do
  let(:autoyast_proposals) { [] }

  before do
    # mock constant to avoid dependency on autoyast
    autoinst_config = double(Confirm: false, getProposalList: autoyast_proposals)
    stub_const("Yast::AutoinstConfig", autoinst_config)
    allow(Yast::UI).to receive(:UserInput).and_return(:accept)
  end

  describe ".new" do
    it "Allows passing different store implementation" do
      class C < ::Installation::ProposalStore; end
      expect { ::Installation::ProposalRunner.new(C) }.to_not raise_error
    end
  end

  describe "#run" do
    PROPERTIES = {
      "enable_skip" => "no",
      "label" => "Installation Settings",
      "mode" => "autoinstallation",
      "name" => "initial",
      "stage" => "initial",
      "unique_id" => "auto_inst_proposal",
      "proposal_modules" => [
        { "name" => "hwinfo", "presentation_order" => "90" },
        { "name" => "keyboard", "presentation_order" => "15" }
      ],
    }.freeze

    let(:properties) { PROPERTIES }
    let(:proposals) { [["keyboard_proposal", 90], ["hwinfo_proposal", 15]] }

    before do
      allow(Yast::ProductControl).to receive(:getProposalProperties)
        .and_return(properties)
      allow(Yast::ProductControl).to receive(:getProposals)
        .and_return(proposals)
      allow_any_instance_of(::Installation::ProposalStore).to receive(:proposal_names)
        .and_return(proposals.map(&:first))
    end

    it "do nothing if run non-interactive" do
      allow(Yast::Mode).to receive(:autoinst).and_return(true)

      expect(subject.run).to eq :auto
    end

    it "do nothing if given proposal type is disabled" do
      allow(Yast::ProductControl).to receive(:GetDisabledProposals).and_return(["initial"])
      allow(Yast::GetInstArgs).to receive(:proposal).and_return("initial")

      expect(subject.run).to eq :auto
    end

    it "passes a smoke test" do
      expect { subject.run }.to_not raise_error
    end

    context "when proposal contains tabs" do
      let(:properties) do
        PROPERTIES.merge({
          "proposal_tabs" => [
            { "label" => "Overview", "proposal_modules" => ["keyboard"] },
            { "label" => "Expert", "proposal_modules" => ["hwinfo", "keyboard"] }
          ]
        })
      end

      it "makes a proposal" do
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("keyboard_proposal", anything).and_return({"preformatted_proposal" => ""})
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("hwinfo_proposal", anything).and_return({"preformatted_proposal" => ""})
        expect(subject.run).to eq(:next)
      end

      context "and the proposal screen is configured through AutoYaST" do
        let(:autoyast_proposals) { ["keyboard_proposal"] } # check bsc#1013976

        it "makes a proposal" do
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("keyboard_proposal", anything).and_return({"preformatted_proposal" => ""})
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("hwinfo_proposal", anything).and_return({"preformatted_proposal" => ""})
          expect(subject.run).to eq(:next)
        end
      end
    end

    context "when proposal does not contain tabs" do
      it "makes a proposal" do
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("keyboard_proposal", anything).and_return({"preformatted_proposal" => ""})
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("hwinfo_proposal", anything).and_return({"preformatted_proposal" => ""})
        expect(subject.run).to eq(:next)
      end

      context "and the proposal screen is configured through AutoYaST" do
        let(:autoyast_proposals) { ["keyboard_proposal"] } # check bsc#1013976

        it "makes a proposal" do
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("keyboard_proposal", anything).and_return({"preformatted_proposal" => ""})
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("hwinfo_proposal", anything).and_return({"preformatted_proposal" => ""})
          expect(subject.run).to eq(:next)
        end
      end
    end
  end
end

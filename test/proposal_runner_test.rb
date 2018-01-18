#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/proposal_runner"

Yast.import "ProductControl"
Yast.import "GetInstArgs"
Yast.import "Mode"
Yast.import "Packages"

describe ::Installation::ProposalRunner do
  let(:autoyast_proposals) { [] }

  before do
    # mock constant to avoid dependency on autoyast
    autoinst_config = double(Confirm: false, getProposalList: autoyast_proposals)
    stub_const("Yast::AutoinstConfig", autoinst_config)
    autoinst_functions = double(check_second_stage_environment: "")
    stub_const("Yast::AutoinstFunctions", autoinst_functions)
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
      "enable_skip"      => "no",
      "label"            => "Installation Settings",
      "mode"             => "autoinstallation",
      "name"             => "initial",
      "stage"            => "initial",
      "unique_id"        => "auto_inst_proposal",
      "proposal_modules" => [
        { "name" => "hwinfo", "presentation_order" => "90" },
        { "name" => "keyboard", "presentation_order" => "15" }
      ]
    }.freeze

    let(:properties) { PROPERTIES }
    let(:proposals) { [["keyboard_proposal", 90], ["hwinfo_proposal", 15]] }
    let(:keyboard_description) do
      { "id" => "keyboard_stuff", "menu_title" => "&Keyboard Layout", "rich_text_title" => "Keyboard Layout" }
    end
    let(:hwinfo_description) do
      { "id" => "init_hwinfo", "menu_title" => "S&ystem", "rich_text_title" => "System" }
    end

    before do
      allow(Yast::ProductControl).to receive(:getProposalProperties)
        .and_return(properties)
      allow(Yast::ProductControl).to receive(:getProposals)
        .and_return(proposals)
      allow_any_instance_of(::Installation::ProposalStore).to receive(:proposal_names)
        .and_return(proposals.map(&:first))
      allow(Yast::WFM).to receive(:CallFunction).and_call_original
      allow(Yast::WFM).to receive(:CallFunction)
        .with("keyboard_proposal", ["Description", {}]).and_return(keyboard_description)
      allow(Yast::WFM).to receive(:CallFunction)
        .with("hwinfo_proposal", ["Description", {}]).and_return(hwinfo_description)
      # Language class is missing in buildroot -> mock it
      allow(Yast::Language).to receive(:language).and_return("en_US")
    end

    it "checks remote/second_stage environment and returns -auto- in autoyast mode" do
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
      expect(Yast::Packages).to receive(:check_remote_installation_packages).and_return("")
      expect(Yast::Report).not_to receive(:Warning)
      expect(subject.run).to eq :auto
    end

    it "do nothing if given proposal type is disabled" do
      allow(Yast::ProductControl).to receive(:GetDisabledProposals).and_return(["initial"])
      allow(Yast::GetInstArgs).to receive(:proposal).and_return("initial")

      expect(subject.run).to eq :auto
    end

    describe "#html_header" do
      it "returns clickable header when forced" do
        allow(Yast::GetInstArgs).to receive(:proposal).and_return("software")

        expect_any_instance_of(::Installation::ProposalRunner)
          .to receive(:submod_descriptions_and_build_menu)
          .and_return(false)
        expect_any_instance_of(::Installation::ProposalStore)
          .to receive(:title_for)
          .and_return("Software")
        expect_any_instance_of(::Installation::ProposalStore)
          .to receive(:id_for)
          .and_return("software")
        expect_any_instance_of(::Installation::ProposalStore)
          .not_to receive(:read_only?)

        # initialization of internal state
        expect(subject.run).to eq :auto

        expect(subject.send(:html_header, "software", force_rw: true)).to eql Yast::HTML.Heading(Yast::HTML.Link("Software", "software"))
      end
    end

    context "when proposal contains tabs" do
      let(:properties) do
        PROPERTIES.merge(
          "proposal_tabs" => [
            { "label" => "Overview", "proposal_modules" => ["keyboard"] },
            { "label" => "Expert", "proposal_modules" => ["hwinfo", "keyboard"] }
          ]
        )
      end

      it "makes a proposal" do
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("keyboard_proposal", anything).and_return("preformatted_proposal" => "")
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("hwinfo_proposal", anything).and_return("preformatted_proposal" => "")
        expect(subject.run).to eq(:next)
      end

      context "and the proposal screen is configured through AutoYaST" do
        let(:autoyast_proposals) { ["keyboard_proposal"] } # check bsc#1013976

        it "makes a proposal" do
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("keyboard_proposal", anything).and_return("preformatted_proposal" => "")
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("hwinfo_proposal", anything).and_return("preformatted_proposal" => "")
          expect(subject.run).to eq(:next)
        end
      end
    end

    context "when proposal does not contain tabs" do
      it "makes a proposal" do
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("keyboard_proposal", anything).and_return("preformatted_proposal" => "")
        expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
          .with("hwinfo_proposal", anything).and_return("preformatted_proposal" => "")
        expect(subject.run).to eq(:next)
      end

      context "and the proposal screen is configured through AutoYaST" do
        let(:autoyast_proposals) { ["keyboard_proposal"] } # check bsc#1013976

        it "makes a proposal" do
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("keyboard_proposal", anything).and_return("preformatted_proposal" => "")
          expect_any_instance_of(::Installation::ProposalStore).to receive(:make_proposal)
            .with("hwinfo_proposal", anything).and_return("preformatted_proposal" => "")
          expect(subject.run).to eq(:next)
        end
      end

      context "and it enables soft r/o proposal in case of error" do
        PROPERTIES = {
          "enable_skip"      => "no",
          "label"            => "Installation Settings",
          "mode"             => "autoinstallation",
          "name"             => "initial",
          "stage"            => "initial",
          "unique_id"        => "auto_inst_proposal",
          "proposal_modules" => [
            { "name" => "software", "presentation_order" => "15", "read_only" => "soft" }
          ]
        }.freeze
        let(:proposals) { [["software_proposal", 15]] }

        it "makes a proposal" do
          allow(subject)
            .to receive(:html_header)
            .with("software_proposal")
            .and_call_original

          # we need ProposalStore#make_proposal to call the callback
          allow(Yast::WFM)
            .to receive(:CallFunction)
            .and_return(
              "preformated_proposal" => "",
              "warning_level"        => :error
            )

          expect(subject)
            .to receive(:html_header)
            .with("software_proposal", force_rw: true)
            .at_least(:once)
            .and_call_original
          expect(subject.run).to eq(:next)
        end
      end
    end
  end
end

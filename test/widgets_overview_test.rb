#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/widgets/overview"

# TODO: these shared examples will soon be available in yast2.rpm
# and then we can just `require "cwm/rspec"`
RSpec.shared_examples "CWM::AbstractWidget" do
  context "these methods are only tested if they exist" do
    describe "#label" do
      it "produces a String" do
        next unless subject.respond_to?(:label)
        expect(subject.label).to be_a String
      end
    end

    describe "#help" do
      it "produces a String" do
        next unless subject.respond_to?(:help)
        expect(subject.help).to be_a String
      end
    end

    describe "#opt" do
      it "produces Symbols" do
        next unless subject.respond_to?(:opt)
        expect(subject.opt).to be_an Enumerable
        subject.opt.each do |o|
          expect(o).to be_a Symbol
        end
      end
    end

    describe "#handle" do
      it "produces a Symbol or nil" do
        next unless subject.respond_to?(:handle)
        m = subject.method(:handle)
        args = m.arity == 0 ? [] : [:dummy_event]
        expect(subject.handle(* args)).to be_a(Symbol).or be_nil
      end
    end

    describe "#validate" do
      it "produces a Boolean (or nil)" do
        next unless subject.respond_to?(:validate)
        expect(subject.validate).to be(true).or be(false).or be_nil
      end
    end
  end
end

RSpec.shared_examples "CWM::CustomWidget" do
  include_examples "CWM::AbstractWidget"
  describe "#contents" do
    it "produces a Term" do
      expect(subject.contents).to be_a Yast::Term
    end
  end
end

describe Y2Caasp::Widgets::Overview do
  subject { Y2Caasp::Widgets::Overview.new(client: "adventure") }
  let(:description) do
    {
      "menu_title" => "An Unexpected Journey"
    }
  end
  let(:proposal) do
    {
      "label_proposal" => ["Walk to the Lonely Mountain", "Take Gold and Reign"]
    }
  end
  let(:proposal_oops) do
    {
      "label_proposal" => ["Walk to the Lonely Mountain", "Take Gold and Reign"],
      "warning"        => "Dragon guarding the gold, no thief in your party",
      "warning_level"  => :fatal
    }
  end

  before do
    allow(Yast::WFM).to receive(:CallFunction)
      .with("adventure", ["Description", {}])
      .and_return(description)
    allow(Yast::WFM).to receive(:CallFunction)
      .with("adventure", ["MakeProposal", { "simple_mode" => true }])
      .and_return(proposal)
    allow(Yast::WFM).to receive(:CallFunction)
      .with("adventure", ["AskUser", {}])
  end

  include_examples "CWM::CustomWidget"
  context "when there is a problem" do
    before do
      allow(Yast::WFM).to receive(:CallFunction)
        .with("adventure", ["MakeProposal", { "simple_mode" => true }])
        .and_return(proposal_oops)
    end

    describe "#validate" do
      it "returns false" do
        subject.contents
        expect(subject.validate).to be false
      end
    end
  end

  context "when there is a problem and the user corrects it" do
    before do
      allow(Yast::WFM).to receive(:CallFunction)
        .with("adventure", ["MakeProposal", { "simple_mode" => true }])
        .and_return(proposal_oops, proposal)
    end

    describe "#validate" do
      it "first returns false, then returns true" do
        subject.contents
        expect(subject.validate).to be false

        subject.handle(:hire_mr_baggins)

        subject.contents
        expect(subject.validate).to be true
      end
    end
  end
end

#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

require "installation/cio_ignore"

describe ::Installation::CIOIgnoreProposal do

  subject { ::Installation::CIOIgnoreProposal.new }

  before(:each) do
    ::Installation::CIOIgnore.instance.reset
  end

  describe "#run" do
    it "returns proposal entry hash when \"MakeProposal\" passed" do
      result = subject.run(["MakeProposal"])

      expect(result).to have_key("links")
      expect(result).to have_key("help")
      expect(result).to have_key("preformatted_proposal")
    end

    it "returns proposal metadata hash when \"Description\" passed" do
      result = subject.run(["Description"])

      expect(result).to have_key("rich_text_title")
      expect(result).to have_key("menu_title")
      expect(result).to have_key("id")
    end

    it "changes proposal if \"AskUser\" passed with chosen_id in second param hash" do
      params = [
        "AskUser",
        "chosen_id" => ::Installation::CIOIgnoreProposal::CIO_DISABLE_LINK
      ]
      result = subject.run(params)

      expect(result["workflow_sequence"]).to eq :next
      expect(::Installation::CIOIgnore.instance.enabled).to be false
    end

    it "raises RuntimeError if \"AskUser\" passed without chosen_id in second param hash" do
      expect{subject.run(["AskUser"])}.to(
        raise_error(RuntimeError)
      )
    end

    it "raises RuntimeError if \"AskUser\" passed with non-existing chosen_id in second param hash" do
      params = [
        "AskUser",
        "chosen_id" => "non_existing"
      ]

      expect{subject.run(params)}.to raise_error(RuntimeError)
    end

    it "raises RuntimeError if unknown action passed as first parameter" do
      expect{subject.run(["non_existing_action"])}.to(
        raise_error(RuntimeError)
      )
    end
  end
end


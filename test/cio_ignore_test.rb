#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

require "installation/cio_ignore"

describe ::Installation::CIOIgnoreProposal do
  describe "#run" do
   it "returns proposal entry hash when \"MakeProposal\" passed" do
     result = ::Installation::CIOIgnoreProposal.new.run(["MakeProposal"])

     expect(result).to have_key("links")
     expect(result).to have_key("help")
     expect(result).to have_key("preformatted_proposal")
   end
  end
end


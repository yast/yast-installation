#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/clients/inst_finish"

describe Yast::InstFinishClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:ClientExists).and_return(true)
      allow(Yast::WFM).to receive(:CallFunction).with(anything, ["Info"])
        .and_return({})
      allow(Yast::WFM).to receive(:CallFunction).with(anything, ["Write"])
      allow(Yast::UI).to receive(:PollInput)
    end

    it "return :next if not aborted" do
      expect(subject.main).to eq :next
    end

    it "return :abort if aborted by user and confirmed" do
      expect(Yast::UI).to receive(:PollInput).and_return(:abort)
      expect(Yast::Popup).to receive(:ConfirmAbort).and_return(true)

      expect(subject.main).to eq :abort
    end

    it "returns :auto if going back in installation" do
      expect(Yast::GetInstArgs).to receive(:going_back).and_return(true)

      expect(subject.main).to eq :auto
    end
  end
end

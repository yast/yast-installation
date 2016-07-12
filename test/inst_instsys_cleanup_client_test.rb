#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/clients/inst_instsys_cleanup_client"

describe Yast::InstInstsysCleanupClient do
  describe ".main" do
    context "when going forward in the installation" do
      before do
        expect(Yast::GetInstArgs).to receive(:going_back).and_return(false)
      end

      it "runs the cleaner" do
        expect(Installation::InstsysCleaner).to receive(:make_clean)

        subject.main
      end

      it "returns :next" do
        allow(Installation::InstsysCleaner).to receive(:make_clean)

        expect(subject.main).to eq(:next)
      end
    end

    context "when going back in the installation" do
      before do
        expect(Yast::GetInstArgs).to receive(:going_back).and_return(true)
      end

      it "does not run the cleaner" do
        expect(Installation::InstsysCleaner).to_not receive(:make_clean)

        subject.main
      end

      it "returns :back" do
        expect(Installation::InstsysCleaner).to_not receive(:make_clean)

        expect(subject.main).to eq(:back)
      end
    end
  end
end

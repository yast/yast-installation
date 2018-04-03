#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/inst_confirm"

describe Yast::InstConfirmDialog do
  subject(:confirm) { Yast::InstConfirmDialog.new }

  describe "#run" do
    before do
      allow(Yast::Pkg).to receive(:SourceGetCurrent).and_return([])
    end

    context "Installation mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(false)
        expect(Yast::Label).to receive(:InstallButton)
      end

      context "data is already on disk" do
        it "reports delete warning" do
          expect(Yast::Storage).to receive(:GetCommitInfos).and_return([{:destructive => true}])
          confirm.run(false)
        end
      end
 
    end

    context "Update mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(true)
      end
    end
  end
end

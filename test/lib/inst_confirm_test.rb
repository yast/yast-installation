#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/inst_confirm"

describe Yast::InstConfirmDialog do
  subject(:confirm) { Yast::InstConfirmDialog.new }

  describe "#run" do
    before do
      allow(Yast::Pkg).to receive(:SourceGetCurrent).and_return([])
      allow(Yast::ProductLicense).to receive(:info_seen!).with(0)
      allow(Yast::Storage).to receive(:GetCommitInfos).and_return([{:destructive => true}])
    end

    context "installation mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(false)
        expect(Yast::Label).to receive(:InstallButton)
      end

     context "no license confirmation UI" do
       it "returns true if the user clicks ok" do
         expect(Yast::UI).to receive(:UserInput).and_return(:ok)
         expect(confirm.run(false)).to eq(true)
       end

       it "returns false if the user clicks abort" do
         expect(Yast::UI).to receive(:UserInput).and_return(:abort)
         expect(confirm.run(false)).to eq(false)
       end
     end

     context "license confirmation UI" do
       before do
         expect(Yast::ProductLicense).to receive(:AcceptanceNeeded).and_return(true)
         expect(Yast::ProductLicense).to receive(:ShowLicenseInInstallation).with(
           :base_license_rp, 0)
       end

       context "user clicks ok" do
         before do
           expect(Yast::UI).to receive(:UserInput).and_return(:ok)
         end

         it "returns true if the user has accepted license" do
           allow(Yast::InstData).to receive(:product_license_accepted).and_return(true)
           expect(confirm.run(true)).to eq(true)
         end
       end

       context "user clicks abort" do
         before do
           expect(Yast::UI).to receive(:UserInput).and_return(:abort)
         end

         it "returns false if the user has not accepted license" do
           allow(Yast::InstData).to receive(:product_license_accepted).and_return(false)
           expect(confirm.run(true)).to eq(false)
         end

         it "returns false even if the user has accepted license" do
           allow(Yast::InstData).to receive(:product_license_accepted).and_return(true)
           expect(confirm.run(true)).to eq(false)
         end
       end
     end
 
    end

    context "update mode" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(true)
      end

      it "shows the upgrade button" do
        expect(Yast::Label).not_to receive(:InstallButton)
        expect(Yast::UI).to receive(:UserInput).and_return(:ok)
        expect(confirm.run(false)).to eq(true)
      end
    end
  end
end

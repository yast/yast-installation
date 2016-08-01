#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_complex_welcome"

describe Yast::InstComplexWelcomeClient do
  Yast.import "Mode"
  Yast.import "ProductLicense"

  textdomain "installation"

  let(:store_path) { File.join(File.dirname(__FILE__), "complex_welcome_store.yaml") }

  before do
    stub_const("Yast::InstComplexWelcomeClient::DATA_PATH", store_path)
    allow(Yast::ProductLicense).to receive(:info_seen?) { true }
    # fake yast2-country, to avoid additional build dependencies
    stub_const("Yast::Console", double.as_null_object)
    stub_const("Yast::Keyboard", double.as_null_object)
    stub_const("Yast::Timezone", double.as_null_object)
    # stub complete UI, as if it goes thrue component system it will get one of
    # null object returned above as parameter and it raise exception from
    # component system
    stub_const("Yast::UI", double.as_null_object)
  end

  after do
    FileUtils.rm(store_path) if File.exist?(store_path)
  end

  describe "#main" do
    let(:restarting) { false }
    context "when installation Mode is auto" do
      it "returns :auto" do
        expect(Yast::Mode).to receive(:autoinst) { true }

        expect(subject.main).to eql(:auto)
      end
    end

    context "when installation mode is not auto" do
      before do
        expect(Yast::Mode).to receive(:autoinst) { false }
        allow(Yast::Installation).to receive(:restarting?) { restarting }
      end

      context "and installer is restarting" do
        let(:restarting) { true }
        it "applies data if exists and returns next" do
          allow(subject).to receive(:data_stored?) { true }
          expect(subject).to receive(:apply_data)

          expect(subject.main).to eql(:next)
        end

        it "does not apply data if not exists and continues as not restarting" do
          allow(subject).to receive(:data_stored?) { false }
          expect(subject).not_to receive(:apply_data)
          allow(subject).to receive(:event_loop)
          expect(subject).to receive(:initialize_dialog)

          subject.main
        end
      end

      context "and installer is not restarting" do
        before do
          allow(subject).to receive(:data_stored?) { false }
        end

        it "initializes dialog" do
          allow(subject).to receive(:event_loop)
          expect(subject).to receive(:initialize_dialog)

          subject.main
        end

        it "starts input loop" do
          expect(subject).to receive(:initialize_dialog)
          expect(subject).to receive(:event_loop)

          subject.main
        end

        context "when back is selected" do

          it "returns back" do
            expect(subject).to receive(:initialize_dialog)
            expect(Yast::UI).to receive(:UserInput).and_return(:back)

            expect(subject.main).to eql(:back)
          end
        end

        context "when next is selected" do
          before do
            allow(Yast::Mode).to receive(:config).and_return(false)
            allow(Yast::Stage).to receive(:initial).and_return(true)

            allow(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(true)
            allow(Yast::Language).to receive(:CheckLanguagesSupport)

            allow(Yast::ProductLicense).to receive(:AcceptanceNeeded).and_return(license_needed)
            allow(subject).to receive(:license_accepted?).and_return(license_accepted)
          end

          context "when license is required and not accepted" do
            let(:license_needed) { true }
            let(:license_accepted) { false }

            it "not returns" do
              expect(Yast::UI).to receive(:UserInput).and_return(:next, :back)
              expect(Yast::Report).to receive(:Message)
                .with(_("You must accept the license to install this product"))
              expect(subject.main).to eql(:back)
            end
          end

          context "when license is not required" do
            let(:license_needed) { false }
            let(:license_accepted) { false }

            it "stores selected data and returns next" do
              expect(Yast::UI).to receive(:UserInput).and_return(:next)
              expect(subject).to receive(:setup_final_choice)
              expect(subject).to receive(:store_data)
              expect(Yast::Report).to_not receive(:Message)

              expect(subject.main).to eql(:next)
            end
          end

          context "when license is required and accepted" do
            let(:license_needed) { true }
            let(:license_accepted) { true }

            it "stores selected data and returns next" do
              expect(Yast::UI).to receive(:UserInput).and_return(:next)
              expect(subject).to receive(:setup_final_choice)
              expect(subject).to receive(:store_data)
              expect(Yast::Report).to_not receive(:Message)

              expect(subject.main).to eql(:next)
            end
          end
        end
      end
    end
  end
end

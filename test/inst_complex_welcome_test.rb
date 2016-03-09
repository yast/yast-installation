#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_complex_welcome"


describe Yast::InstComplexWelcomeClient do

  describe "#main" do
    context "when installation Mode is auto" do
      it "returns :auto" do
        expect(Yast::Mode).to receive(:autoinst) { true }

        expect(subject.main).to eql(:auto)
      end
    end

    context "when installation mode is not auto" do
      before do
        expect(Yast::Mode).to receive(:autoinst) { false }
      end

      context "and previous data exist" do
        it "applies data and returns :next" do
          allow(subject).to receive(:data_stored?) { true }
          expect(subject).to receive(:apply_data)

          expect(subject.main).to eql(:next)
        end
      end

      context "and no previous data exist" do
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
            expect(Yast::Mode).to receive(:config) { false }
            expect(subject).to receive(:initialize_dialog)
          end

          context "when license is required and not accepted" do
            it "not returns" do
              expect(Yast::UI).to receive(:UserInput).and_return(:next, :back)
              expect(subject).to receive(:read_ui_state)
              expect(subject).to receive(:license_required) { true }
              expect(subject).to receive(:license_accepted?) { false }

              expect(subject.main).to eql(:back)
            end
          end

          context "when license is not required or is required and accepted" do
            it "stores selected data and returns next" do
              expect(Yast::UI).to receive(:UserInput).and_return(:next)
              expect(subject).to receive(:read_ui_state)

              expect(subject).to receive(:license_required) { true }
              expect(subject).to receive(:license_accepted?) { true }
              expect(Yast::Language).to receive(:CheckIncompleteTranslation) { true }
              expect(Yast::Stage).to receive (:initial) { false }

              expect(subject).to receive(:setup_final_choice)

              expect(subject).to receive(:store_data)
              expect(subject.main).to eql(:next)
            end
          end
        end

      end

    end
  end

end

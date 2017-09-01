#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_complex_welcome"

describe Yast::InstComplexWelcomeClient do
  textdomain "installation"

  let(:product) do
    instance_double(
      Y2Packager::Product,
      license_confirmation_required?: license_needed?,
      license?:                       license?,
      license:                        "license content",
      license_confirmed?:             license_confirmed?
    )
  end
  let(:license_needed?) { true }
  let(:license_confirmed?) { false }
  let(:license?) { true }
  let(:other_product) { instance_double(Y2Packager::Product) }
  let(:products) { [product, other_product] }
  let(:autoinst) { false }
  let(:config_mode) { false }

  before do
    # fake yast2-country, to avoid additional build dependencies
    stub_const("Yast::Console", double.as_null_object)
    stub_const("Yast::Keyboard", double(current_kbd: "english-us", GetKeyboardItems: [], user_decision: true))
    stub_const("Yast::Timezone", double.as_null_object)
    stub_const("Yast::Language",
      double(language: "en_US", GetLanguageItems: [], CheckIncompleteTranslation: true))
    stub_const("Yast::Wizard", double.as_null_object)
    stub_const("Yast::ProductLicense", double.as_null_object)
    stub_const("Yast::Mode", double(autoinst: autoinst, normal: false, config: config_mode))
    # stub complete UI, as if it goes thrue component system it will get one of
    # null object returned above as parameter and it raise exception from
    # component system

    allow(Y2Packager::Product).to receive(:selected_base).and_return(product)
    allow(Y2Packager::Product).to receive(:available_base_products).and_return(products)
  end

  describe "#main" do
    let(:restarting) { false }
    let(:dialog_results) { [:back] }

    before do
      allow(Installation::Dialogs::ComplexWelcome).to receive(:run).and_return(*dialog_results)
    end

    context "when README.BETA file exists" do
      before do
        allow(Yast::FileUtils).to receive(:Exists).with("/README.BETA")
          .and_return(true)
        allow(Yast::GetInstArgs).to receive(:going_back).and_return(false)
        allow(subject).to receive(:event_loop)
        allow(Yast::ProductLicense).to receive(:AcceptanceNeeded).and_return(false)
      end

      it "shows the information contained in the file" do
        expect(Yast::InstShowInfo).to receive(:show_info_txt).with("/README.BETA")
        subject.main
      end
    end

    context "when installation Mode is auto" do
      let(:autoinst) { true }

      it "returns :auto" do
        expect(subject.main).to eql(:auto)
      end
    end

    it "runs the dialog" do
      subject.main
    end

    context "when back is pressed" do
      let(:dialog_results) { [:back] }

      it "returns :back" do
        expect(subject.main).to eq(:back)
      end
    end

    context "when language changes" do
      let(:dialog_results) { [:language_changed] }

      it "returns :again" do
        allow(subject).to receive(:change_language)
        expect(subject.main).to eq(:again)
      end

      it "changes the language" do
        expect(subject).to receive(:change_language)
        subject.main
      end

      context "and running in config mode" do
        let(:config_mode) { true }
        let(:dialog_results) { [:language_changed, :back] }

        before do
        end

        it "does not change the language" do
          expect(subject).to_not receive(:change_language)
          subject.main
        end
      end
    end

    context "when keyboard changes" do
      it "sets the selection as user selected" do
        allow(Installation::Dialogs::ComplexWelcome).to receive(:run).and_return(:keyboard_changed, :back)
        expect(Yast::Keyboard).to receive(:user_decision=).with(true)
        subject.main
      end

      it "reruns the dialog" do
        expect(Installation::Dialogs::ComplexWelcome).to receive(:run).twice
          .and_return(:keyboard_changed, :back)
        allow(Yast::Keyboard).to receive(:user_decision=)
        subject.main
      end
    end

    context "when :next is pressed" do
      let(:dialog_results) { [:next] }
      let(:selected_product) { product }

      before do
        allow(subject).to receive(:setup_final_choice)
        allow(subject).to receive(:selected_product).and_return(selected_product)
        allow(Yast::WorkflowManager).to receive(:merge_product_workflow)
        allow(Yast::ProductControl).to receive(:RunFrom)
      end

      it "sets up according to chosen values" do
        expect(subject).to receive(:setup_final_choice)
        subject.main
      end

      it "returns :next" do
        expect(subject.main).to eq(:next)
      end

      context "when a product was selected" do
        it "merges the product's workflow" do
          expect(Yast::WorkflowManager).to receive(:merge_product_workflow)
            .with(selected_product)
          subject.main
        end

        it "returns :next" do
          allow(Yast::WorkflowManager).to receive(:merge_product_workflow)
          expect(subject.main).to eq(:next)
        end
      end

      context "when no product was selected" do
        let(:dialog_results) { [:next, :back] }
        let(:selected_product) { nil }

        it "reports an error" do
          expect(Yast::Popup).to receive(:Error)
          subject.main
        end
      end

      context "when language support is incomplete" do
        let(:dialog_results) { [:next, :back] }

        it "warns the user" do
          expect(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(true)
          subject.main
        end

        it "returns :next if user accepts" do
          expect(subject.main).to eq(:next)

        end

        it "returns to the dialog if the user does not accept" do
          allow(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(false)

          expect(::Installation::Dialogs::ComplexWelcome).to receive(:run).twice
          expect(subject.main).to eq(:back)
        end
      end

      context "when running in config mode" do
        let(:dialog_results) { [:next, :back] }
        let(:config_mode) { true }

        it "returns nil" do
          expect(::Installation::Dialogs::ComplexWelcome).to receive(:run).twice
          subject.main
        end
      end
    end

    context "when :abort is pressed" do
      let(:dialog_results) { [:abort] }

      it "asks for confirmation" do
        expect(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(true)
        subject.main
      end

      context "and user confirms" do
        it "returns :abort" do
          allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(true)
          expect(Installation::Dialogs::ComplexWelcome).to receive(:run).and_return(:abort)
          expect(subject.main).to eq(:abort)
        end
      end

      context "and user does not confirm" do
        it "reruns the dialog" do
          allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(false, true)
          expect(Installation::Dialogs::ComplexWelcome).to receive(:run).twice.and_return(:abort, :abort)
          subject.main
        end
      end
    end
  end
end

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
  let(:auto) { false }
  let(:config_mode) { false }
  let(:update_mode) { false }
  let(:language) { "en_US" }

  let(:language_mock) do
    double(
      language:                   language,
      languages:                  "en_US,de_DE",
      GetLanguageItems:           [],
      CheckIncompleteTranslation: true,
      Save:                       nil,
      SetDefault:                 nil
    )
  end

  let(:keyboard_mock) do
    double(current_kbd: "english-us", GetKeyboardItems: [], user_decision: true, Save: nil)
  end

  let(:mode_mock) do
    double(
      auto: auto, normal: false, config: config_mode,
      update: update_mode, live_installation: false
    )
  end

  before do
    # fake yast2-country, to avoid additional build dependencies
    stub_const("Yast::Console", double.as_null_object)
    stub_const("Yast::Keyboard", keyboard_mock)
    stub_const("Yast::Timezone", double.as_null_object)
    stub_const("Yast::Language", language_mock)
    stub_const("Yast::Wizard", double.as_null_object)
    stub_const("Yast::ProductLicense", double.as_null_object)
    stub_const("Yast::Mode", mode_mock)

    allow(Y2Packager::Product).to receive(:selected_base).and_return(product)
    allow(Y2Packager::Product).to receive(:available_base_products).and_return(products)
  end

  describe "#main" do
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
      let(:auto) { true }

      it "returns :auto" do
        expect(subject.main).to eql(:auto)
      end
    end

    it "runs the dialog" do
      expect(Installation::Dialogs::ComplexWelcome).to receive(:run)
        .and_return(:back)
      subject.main
    end

    it "handles the dialog result" do
      expect(Installation::Dialogs::ComplexWelcome).to receive(:run)
        .and_return(:back)
      expect(subject).to receive(:handle_dialog_result).with(:back)
        .and_return(:back)

      subject.main
    end

    context "depending on the result of the handling" do
      it "returns to the dialog if no result" do
        expect(::Installation::Dialogs::ComplexWelcome).to receive(:run).twice
          .and_return(:next, :abort)
        expect(subject).to receive(:handle_dialog_result).with(:next)
          .and_return(nil)
        expect(subject).to receive(:handle_dialog_result).with(:abort)
          .and_return(:abort)

        subject.main
      end

      context "when no product is available for select" do
        let(:dialog_results) { [:next] }
        let(:productse) { [] }

        it "returns the result" do
          expect(subject).to receive(:handle_dialog_result)
            .with(:next).and_return(:handling_result)

          expect(subject.main).to eql(:handling_result)
        end
      end

      context "there is some product to select" do
        let(:dialog_results) { [:next] }

        it "returns the result if different than :next" do
          expect(subject).to receive(:handle_dialog_result)
            .with(:next).and_return(:handling_result)

          expect(subject.main).to eql(:handling_result)
        end

        it "executes from next step" do
          expect(subject).to receive(:handle_dialog_result)
            .with(:next).and_return(:next)
          expect(subject).to receive(:merge_and_run_workflow)

          subject.main
        end
      end
    end
  end

  describe "#handling_dialog_result" do
    context "when :back is given" do
      it "returns :back" do
        expect(subject.handle_dialog_result(:back)).to eq(:back)
      end
    end

    context "when :abort is given" do
      it "asks for confirmation" do
        expect(Yast::Popup).to receive(:ConfirmAbort).with(:painless)
        subject.handle_dialog_result(:abort)
      end

      context "and user confirms" do
        it "returns :abort" do
          allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(true)
          expect(subject.handle_dialog_result(:abort)).to eq(:abort)
        end
      end

      context "and user does not confirm" do
        it "returns nil" do
          allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(false)
          expect(subject.handle_dialog_result(:abort)).to eq(nil)
        end
      end
    end

    context "when :next is given" do
      before do
        allow(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(true)
        allow(subject).to receive(:product_selection_finished?).and_return(true)
      end

      context "and running in config mode" do
        let(:config_mode) { true }
        it "returns nil" do
          expect(subject.handle_dialog_result(:next)).to eq(nil)
        end
      end

      context "when language support is incomplete" do
        it "warns the user" do
          expect(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(true)

          subject.handle_dialog_result(:next)
        end

        it "returns nil if the user does not accept" do
          expect(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(false)

          expect(subject.handle_dialog_result(:next)).to eq(nil)
        end
      end

      it "sets up according to chosen values" do
        expect(subject).to receive(:setup_final_choice)
        subject.handle_dialog_result(:next)
      end

      it "returns :next" do
        expect(subject.handle_dialog_result(:next)).to eq(:next)
      end

      context "when no products are available" do
        it "returns nil if product selection has not been completed" do
          expect(subject).to receive(:product_selection_finished?).and_return(false)
          expect(subject.handle_dialog_result(:next)).to eq(nil)
        end
      end
    end
  end

  describe "#product_selection_finished?" do
    let(:selected_product) { product }

    before do
      allow(subject).to receive(:selected_product).and_return(selected_product)
    end

    context "when no product was selected" do
      let(:dialog_results) { [:next, :back] }
      let(:selected_product) { nil }

      it "reports an error" do
        expect(Yast::Popup).to receive(:Error)
        subject.send(:product_selection_finished?)
      end
    end

    context "when license was not confirmed" do
      let(:products) { [product] }
      let(:license_confirmed?) { false }

      context "and confirmation is needed" do
        let(:dialog_results) { [:next, :back] }
        let(:license_needed?) { true }

        it "reports an error" do
          expect(Yast::Popup).to receive(:Error)
          subject.send(:product_selection_finished?)
        end
      end

      context "and confirmation was not needed" do
        let(:license_needed?) { false }

        it "does not report an error" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.send(:product_selection_finished?)
        end
      end

      context "when more than 1 product exists (it should be accepted later)" do
        let(:dialog_results) { [:next, :back] }
        let(:license_needed?) { true }
        let(:products) { [product, other_product] }

        it "does not report an error" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.send(:product_selection_finished?)
        end
      end
    end
  end

  describe "#setup_final_choice" do
    let(:initial_stage) { false }

    before do
      allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
    end

    it "sets user decision as default" do
      expect(Yast::Language).to receive(:SetDefault)
      subject.send(:setup_final_choice)
    end

    it "sets the timezone to match the selected language" do
      expect(Yast::Timezone).to receive(:SetTimezoneForLanguage).with(language)
      subject.send(:setup_final_choice)
    end

    it "sets packager locale" do
      expect(Yast::Pkg).to receive(:SetPackageLocale).with(language)
      expect(Yast::Pkg).to receive(:SetTextLocale).with(language)
      subject.send(:setup_final_choice)
    end

    it "saves keyboard and timezone" do
      expect(Yast::Keyboard).to receive(:Save)
      expect(Yast::Timezone).to receive(:Save)
      subject.send(:setup_final_choice)
    end

    context "when running on update mode" do
      let(:update_mode) { true }
      let(:initial_stage) { false }

      it "does not save keyboard nor timezone" do
        expect(Yast::Keyboard).to_not receive(:Save)
        expect(Yast::Timezone).to_not receive(:Save)
        subject.send(:setup_final_choice)
      end
    end

    context "when running on first stage" do
      let(:update_mode) { false }
      let(:initial_stage) { true }

      it "does not save keyboard nor timezone" do
        expect(Yast::Keyboard).to_not receive(:Save)
        expect(Yast::Timezone).to_not receive(:Save)
        subject.send(:setup_final_choice)
      end
    end

    context "when running on live installer" do
      before do
        allow(Yast::Mode).to receive(:live_installation).and_return(true)
        allow(Yast::Language).to receive(:PackagesModified).and_return(lang_packages_needed)
      end

      context "and additional packages are needed for the given language" do
        let(:lang_packages_needed) { true }

        it "adds the packages for installation" do
          expect(Yast::Language).to receive(:PackagesInit).with(["en_US", "de_DE", "en_US"])
          subject.send(:setup_final_choice)
        end
      end

      context "and additional packages are not needed for the given language" do
        let(:lang_packages_needed) { false }

        it "does not add the packages for installation" do
          expect(Yast::Language).to_not receive(:PackagesInit)
          subject.send(:setup_final_choice)
        end
      end
    end
  end
end

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
      autoinst: autoinst, normal: false, config: config_mode,
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
      expect(Installation::Dialogs::ComplexWelcome).to receive(:run)
        .and_return(:back)
      subject.main
    end

    context "release notes" do
      before do
        allow(Yast::InstData).to receive(:release_notes).and_return(release_notes)
      end

      context "when release notes have been downloaded" do
        let(:release_notes) { "release notes" }

        it "show release notes" do
          expect(Yast::Wizard).to receive(:ShowReleaseNotesButton)
          subject.main
        end
      end

      context "when release notes have not been downloaded" do
        let(:release_notes) { "" }

        it "does not download release notes again" do
          expect(Yast::Wizard).to_not receive(:ShowReleaseNotesButton)
          subject.main
        end
      end
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
      let(:dialog_results) { [:keyboard_changed, :back] }

      it "sets the selection as user selected" do
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

      it "returns nil" do
        expect(subject.main).to be_nil
      end

      it "executes from next step" do
        expect(Yast::ProductControl).to receive(:RunFrom)
          .with(Yast::ProductControl.CurrentStep + 1, true)
        subject.main
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

        context "and user accepts" do
          before do
            allow(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(true)
          end

          it "returns nil" do
            expect(subject.main).to be_nil
          end

          it "executes from next step" do
            expect(Yast::ProductControl).to receive(:RunFrom)
              .with(Yast::ProductControl.CurrentStep + 1, true)
            subject.main
          end
        end

        context "and user does not accept" do
          before do
            allow(Yast::Language).to receive(:CheckIncompleteTranslation).and_return(false)
          end

          it "returns to the dialog" do
            expect(::Installation::Dialogs::ComplexWelcome).to receive(:run).twice
            expect(subject.main).to eq(:back)
          end

          it "does not execute from next step" do
            expect(Yast::ProductControl).to_not receive(:RunFrom)
            subject.main
          end
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

  describe "#change_language" do
    # NOTE: we are using #send in order to simplify tests.
    let(:switch_to_english) { false }

    before do
      allow(Yast::Console).to receive(:SelectFont)
      allow(Yast::Language).to receive(:WfmSetGivenLanguage)
      allow(Yast::Language).to receive(:WfmSetLanguage)
      allow(Yast::Language).to receive(:SwitchToEnglishIfNeeded)
        .and_return(switch_to_english)
    end

    it "sets the console font" do
      expect(Yast::Console).to receive(:SelectFont).with(language)
      subject.send(:change_language)
    end

    it "sets the workflow manager language" do
      expect(Yast::Language).to receive(:WfmSetLanguage)
      subject.send(:change_language)
    end

    context "when language is 'nn_NO'" do
      let(:language) { "nn_NO" }

      it "falls back to 'nb_NO'" do
        allow(Yast::Language).to receive(:WfmSetGivenLanguage).with("nb_NO")
        subject.send(:change_language)
      end
    end

    context "when switching to english is needed" do
      let(:switch_to_english) { true }

      it "does not change anything" do
        expect(Yast::Console).to_not receive(:SelectFont)
        expect(Yast::Language).to_not receive(:WfmSetGivenLanguage)
        expect(Yast::Language).to_not receive(:WfmSetLanguage)
        subject.send(:change_language)
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

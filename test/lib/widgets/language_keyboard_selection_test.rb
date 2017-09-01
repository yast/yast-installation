#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/language_keyboard_selection"
require "cwm/rspec"

describe Installation::Widgets::LanguageKeyboardSelection do
  include_examples "CWM::CustomWidget"

  subject(:widget) { described_class.new }

  let(:language) { "de_DE" }
  let(:selected_language) { "de_DE" }
  let(:selected_keyboard) { "english-us" }
  let(:user_decision) { true }
  let(:language_mock) { double("Yast::Language", language: language) }
  let(:keyboard_mock) { double("Yast::Keyboard", user_decision: user_decision, current_kbd: "english-us") }

  let(:keyboard_selection) do
    instance_double("Y2Country::Widgets::KeyboardSelectionCombo", value: selected_keyboard)
  end

  let(:language_selection) do
    instance_double("Y2Country::Widgets::LanguageSelection", value: selected_language)
  end

  let(:keyboard_selection_class) do
    double("Y2Country::Widgets::KeyboardSelectionCombo", new: keyboard_selection)
  end

  let(:language_selection_class) do
    double("Y2Country::Widgets::LanguageSelection", new: language_selection)
  end

  before do
    stub_const("Yast::Language", language_mock)
    stub_const("Yast::Keyboard", keyboard_mock)
    stub_const("Y2Country::Widgets::KeyboardSelectionCombo", keyboard_selection_class)
    stub_const("Y2Country::Widgets::LanguageSelection", language_selection_class)
  end

  describe "#contents" do
    context "keyboard selection" do
      context "when user selected the keyboard" do
        it "uses the selection as the default value" do
          expect(keyboard_selection_class).to receive(:new).with("english-us")
          widget.contents
        end
      end

      context "when user did not selected the keyboard" do
        let(:user_decision) { false }

        before do
          allow(keyboard_mock).to receive(:GetKeyboardForLanguage).and_return("german")
          allow(keyboard_selection_class).to receive(:new)
          allow(keyboard_mock).to receive(:Set)
        end

        it "uses the keyboard which matches the language as default" do
          expect(keyboard_selection_class).to receive(:new).with("german")
          widget.contents
        end

        it "sets keyboard to the default value different" do
          expect(keyboard_mock).to receive(:Set).with("german")
          widget.contents
        end

        context "and keyboard which matches the language is still the same" do
          before do
            allow(keyboard_mock).to receive(:GetKeyboardForLanguage).and_return("english-us")
          end

          it "does not set keyboard" do
            expect(keyboard_mock).to_not receive(:Set)
            widget.contents
          end
        end
      end
    end

    it "uses current language as default" do
      expect(language_selection_class).to receive(:new).with(language)
      widget.contents
    end
  end

  describe "#handle" do
    it "returns nil" do
      expect(widget.handle).to be_nil
    end

    context "when language has changed" do
      let(:selected_language) { "es_ES" }

      it "returns :language_changed" do
        expect(widget.handle).to eq(:language_changed)
      end
    end

    context "when keyboard has changed" do
      let(:selected_keyboard) { "spanish" }

      it "returns :keyboard_changed" do
        expect(widget.handle).to eq(:keyboard_changed)
      end
    end
  end

  describe "#handle_all_events" do
    it "returns true" do
      expect(widget.handle_all_events).to eq(true)
    end
  end
end

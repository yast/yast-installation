#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/dialogs/complex_welcome"

describe Installation::Dialogs::ComplexWelcome do
  subject(:widget) { described_class.new(products) }

  let(:products) { [] }

  describe "#title" do
    it "returns a string" do
      expect(widget.title).to be_a(::String)
    end
  end

  describe "#run" do
    it "retranslates the buttons and side bar" do
      # mock displaying the dialog
      allow(subject).to receive(:should_open_dialog?).and_return(false)
      allow(subject).to receive(:cwm_show).and_return(:next)

      expect(Yast::Wizard).to receive(:RetranslateButtons)
      expect(Yast::ProductControl).to receive(:RetranslateWizardSteps)
      subject.run
    end
  end

  describe "#content" do
    let(:sles_product) { instance_double("Y2Packager::Product", label: "SLES") }
    let(:language_widget) { Yast::Term.new(:language_widget) }
    let(:keyboard_widget) { Yast::Term.new(:keyboard_widget) }
    let(:license_widget) { Yast::Term.new(:license_widget) }
    let(:selector_widget) { Yast::Term.new(:selector_widget) }

    before do
      allow(Y2Country::Widgets::LanguageSelection).to receive(:new)
        .and_return(language_widget)
      allow(Y2Country::Widgets::KeyboardSelectionCombo).to receive(:new)
        .and_return(keyboard_widget)
      allow(Y2Packager::Widgets::ProductLicense).to receive(:new)
        .and_return(license_widget)
      allow(Installation::Widgets::ProductSelector).to receive(:new)
        .and_return(selector_widget)
    end

    it "includes a language/keyboard selection" do
      expect(widget.contents.to_s).to include("language_widget")
      expect(widget.contents.to_s).to include("keyboard_widget")
    end

    context "when only 1 product is available" do
      let(:products) { [sles_product] }

      it "shows the product license" do
        expect(Y2Packager::Widgets::ProductLicense).to receive(:new)
          .with(products.first, skip_validation: true).and_return(license_widget)
        expect(widget.contents.to_s).to include("license_widget")
      end
    end

    context "when more than 1 product is available" do
      let(:sled_product) { instance_double("Y2Packager::Product", label: "SLED") }
      let(:products) { [sles_product, sled_product] }

      it "shows the product selector" do
        expect(Installation::Widgets::ProductSelector).to receive(:new)
          .with(products, skip_validation: true)
        expect(widget.contents.to_s).to include("selector_widget")
      end
    end
  end
end

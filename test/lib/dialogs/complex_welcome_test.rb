#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/dialogs/complex_welcome"

describe Installation::Dialogs::ComplexWelcome do
  before do
    allow(Yast::Language).to receive(:language)
  end

  RSpec.shared_examples "show_license" do
    it "shows the product license" do
      expect(Y2Packager::Widgets::ProductLicense).to receive(:new)
        .with(products.first, skip_validation: true).and_return(license_widget)
      expect(widget.contents.to_s).to include("license_widget")
    end
  end

  RSpec.shared_examples "show_selector" do
    it "shows the product selector" do
      expect(Installation::Widgets::ProductSelector).to receive(:new)
        .with(products, skip_validation: true)
      expect(widget.contents.to_s).to include("selector_widget")
    end
  end

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

  describe "#contents" do
    let(:license) { instance_double("Y2Packager::ProductLicense") }

    let(:sles_product) do
      instance_double("Y2Packager::ProductSpec", label: "SLES", license: license, license?: true)
    end

    let(:sles_online_product) do
      instance_double(
        "Y2Packager::ControlProductSpec", label: "SLES", license: license, license?: true
      )
    end

    let(:sles_offline_product) do
      instance_double("Y2Packager::RepoProductSpec", label: "SLES", license?: true)
    end

    let(:sled_product) do
      instance_double("Y2Packager::Product", label: "SLED", license: license, license?: true)
    end

    let(:sled_online_product) do
      instance_double(
        "Y2Packager::ControlProductSpec", label: "SLED", license: license, license?: true
      )
    end

    let(:sled_offline_product) do
      instance_double("Y2Packager::RepoProductSpec", label: "SLED", license?: true)
    end

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
      context "when it is the normal medium" do
        let(:products) { [sles_product] }
        include_examples "show_license"
      end

      context "when it is the online medium" do
        let(:products) { [sles_online_product] }
        include_examples "show_license"
      end

      context "when it is the offline medium" do
        let(:products) { [sles_offline_product] }
        include_examples "show_license"
      end

      context "when the license is not available" do
        let(:products) { [sles_product] }

        before do
          allow(sles_product).to receive(:license?).and_return(false)
        end

        it "does not show neither the license nor the product selection" do
          expect(Y2Packager::Widgets::ProductLicense).to_not receive(:new)
          expect(Installation::Widgets::ProductSelector).to_not receive(:new)

          widget.contents
        end
      end
    end

    context "when more than 1 product is available" do
      context "when it is the normal medium" do
        let(:products) { [sles_product, sled_product] }
        include_examples "show_selector"
      end
      context "when it is the online medium" do
        let(:products) { [sles_online_product, sled_online_product] }
        include_examples "show_selector"
      end
      context "when it is the offline medium" do
        let(:products) { [sles_offline_product, sled_offline_product] }
        include_examples "show_selector"
      end
    end
  end
end

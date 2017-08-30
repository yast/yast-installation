#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/clients/inst_complex_welcome"

Yast.import "UI"
Yast.import "Mode"
Yast.import "Installation"
Yast.import "Report"
Yast.import "InstShowInfo"
Yast.import "GetInstArgs"

describe Yast::InstComplexWelcomeClient do
  textdomain "installation"

  let(:product) do
    instance_double(
      Y2Packager::Product,
      license_confirmation_required?: license_needed?,
      license?:                       license?,
      license:                        "license content"
    )
  end
  let(:license_needed?) { true }
  let(:license?) { true }

  let(:other_product) { instance_double(Y2Packager::Product) }
  let(:products) { [product, other_product] }

  let(:autoinst) { false }

  before do
    # fake yast2-country, to avoid additional build dependencies
    stub_const("Yast::Console", double.as_null_object)
    stub_const("Yast::Keyboard", double(current_kbd: "english-us", GetKeyboardItems: [], user_decision: true))
    stub_const("Yast::Timezone", double.as_null_object)
    stub_const("Yast::Language", double(language: "en_US", GetLanguageItems: []))
    stub_const("Yast::Wizard", double.as_null_object)
    stub_const("Yast::ProductLicense", double.as_null_object)
    stub_const("Yast::Mode", double(autoinst: autoinst))
    # stub complete UI, as if it goes thrue component system it will get one of
    # null object returned above as parameter and it raise exception from
    # component system

    allow(Y2Packager::Product).to receive(:selected_base).and_return(product)
    allow(Y2Packager::Product).to receive(:available_base_products).and_return(products)
  end

  describe "#main" do
    let(:restarting) { false }
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

    context "when installation mode is not auto" do
      before do
        allow(Yast::Installation).to receive(:restarting?) { restarting }
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

          allow(subject).to receive(:license_required?).and_return(license_needed)
          allow(subject).to receive(:license_accepted?).and_return(license_accepted)
        end

        context "and license is required and not accepted" do
          let(:license_needed) { true }
          let(:license_accepted) { false }

          it "not returns" do
            expect(Yast::UI).to receive(:UserInput).and_return(:next, :back)
            expect(Yast::Report).to receive(:Message)
              .with(_("You must accept the license to install this product"))
            expect(subject.main).to eql(:back)
          end
        end

        context "and license is not required" do
          let(:license_needed) { false }
          let(:license_accepted) { false }

          it "stores selected data and returns next" do
            expect(Yast::UI).to receive(:UserInput).and_return(:next)
            expect(subject).to receive(:setup_final_choice)
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
            expect(Yast::Report).to_not receive(:Message)

            expect(subject.main).to eql(:next)
          end
        end
      end
    end

    context "licensing" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:back)
      end

      it "shows the license for the selected product" do
        allow(Yast::UI).to receive(:ReplaceWidget)
        expect(Yast::UI).to receive(:ReplaceWidget)
          .with(Id(:base_license_rp), RichText(product.license))
        subject.main
      end

      context "when no base products are defined" do
        let(:product) { nil }
        let(:products) { [] }

        it "shows the default license using the old mechanism" do
          expect(Yast::ProductLicense).to receive(:ShowLicenseInInstallation)
            .with(:base_license_rp, anything)
          subject.main
        end
      end

      context "and no license is defined" do
        let(:license?) { false }

        it "shows the default license using the old mechanism" do
          expect(Yast::ProductLicense).to receive(:ShowLicenseInInstallation)
            .with(:base_license_rp, anything)
          subject.main
        end
      end

      context "when no base product is selected" do
        it "does not show any license" do
          expect(Yast::ProductLicense).to_not receive(:ShowLicenseInInstallation)
          subject.main
        end
      end
    end
  end
end

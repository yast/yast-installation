require_relative "../../test_helper"

require "cwm/rspec"

require "y2packager/product"
require "installation/widgets/product_selector"

describe ::Installation::Widgets::ProductSelector do
  let(:product1) { Y2Packager::Product.new(name: "test1", display_name: "Test 1", version: "15", arch: "x86_64") }
  let(:product2) { Y2Packager::Product.new(name: "test2", display_name: "Test 2", version: "15", arch: "x86_64") }
  subject { described_class.new([product1, product2]) }

  include_examples "CWM::RadioButtons"

  before do
    allow(Y2Packager::MediumType).to receive(:offline?).and_return(false)
  end

  describe "#init" do
    let(:registration) { double("Registration::Registration", is_registered?: registered?) }

    before do
      stub_const("Registration::Registration", registration)
      allow(subject).to receive(:require).with("registration/registration")
    end

    context "when the system is registered" do
      let(:registered?) { true }

      it "disables the widget" do
        expect(subject).to receive(:disable)
        subject.init
      end
    end

    context "when the system is not registered" do
      let(:registered?) { false }

      it "does not disable the widget" do
        expect(subject).to_not receive(:disable)
        subject.init
      end
    end

    context "when registration is not available" do
      let(:registered?) { false }

      before do
        allow(subject).to receive(:require).with("registration/registration")
          .and_raise(LoadError)
      end

      it "does not disable the widget" do
        expect(subject).to_not receive(:disable)
        subject.init
      end
    end

    context "when an offline base product has been selected" do
      let(:registered?) { false }

      before do
        expect(Y2Packager::MediumType).to receive(:offline?).and_return(true)
        expect(product1).to receive(:selected?).and_return(true).at_least(:once)
      end

      it "disables the widget" do
        expect(subject).to receive(:disable)
        subject.init
      end
    end
  end

  describe "#store" do
    before do
      allow(Yast::Pkg).to receive(:PkgApplReset)
      allow(Yast::Pkg).to receive(:PkgReset)
      allow(Yast::AddOnProduct).to receive(:selected_installation_products)
        .and_return(["add-on-product"])
      # mock selecting the first product
      allow(subject).to receive(:value).and_return("test1-15-x86_64")
    end

    it "resets previous package configuration" do
      allow(product1).to receive(:select)
      expect(Yast::Pkg).to receive(:PkgApplReset)
      expect(Yast::Pkg).to receive(:PkgReset)
      subject.store
    end

    it "selects the product to install" do
      expect(product1).to receive(:select)
      expect(product2).to_not receive(:select)
      subject.store
    end

    it "reselect add-on products for installation" do
      allow(product1).to receive(:select)
      expect(Yast::Pkg).to receive(:ResolvableInstall)
        .with("add-on-product", :product, "")
      subject.store
    end

    context "offline installation medium" do
      let(:offline_product) { Y2Packager::ProductLocation.new("product", "dir") }
      let(:url) { "http://example.com" }

      before do
        allow(offline_product).to receive(:selected?).and_return(true)
        allow(Yast::InstURL).to receive(:installInf2Url).and_return(url)
        allow(Yast::Packages).to receive(:Initialize_StageInitial)
        allow(Yast::Pkg).to receive(:ResolvableInstall)
        allow(Yast::AddOnProduct).to receive(:SetBaseProductURL)
        allow(Yast::WorkflowManager).to receive(:SetBaseWorkflow)
      end

      it "adds the product repository" do
        expect(Yast::Packages).to receive(:Initialize_StageInitial)
          .with(true, url, url, "dir")

        product_selector = described_class.new([offline_product])
        allow(product_selector).to receive(:value).and_return("dir")
        product_selector.init
        product_selector.store
      end
    end
  end
end

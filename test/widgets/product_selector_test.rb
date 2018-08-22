require_relative "../test_helper"

require "cwm/rspec"

require "y2packager/product"
require "installation/widgets/product_selector"

describe ::Installation::Widgets::ProductSelector do
  let(:product1) { Y2Packager::Product.new(name: "test1", display_name: "Test 1") }
  let(:product2) { Y2Packager::Product.new(name: "test2", display_name: "Test 2") }
  subject { described_class.new([product1, product2]) }

  include_examples "CWM::RadioButtons"

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
  end

  describe "#store" do
    before do
      allow(Yast::Pkg).to receive(:PkgApplReset)
      allow(Yast::Pkg).to receive(:PkgReset)
      allow(Yast::AddOnProduct).to receive(:selected_installation_products)
        .and_return(["add-on-product"])
      # mock selecting the first product
      allow(subject).to receive(:value).and_return("test1")
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
  end
end

require_relative "../test_helper"

require "cwm/rspec"

require "y2packager/product"
require "installation/widgets/product_selector"

describe ::Installation::Widgets::ProductSelector do
  let(:product1) { Y2Packager::Product.new(name: "test1", display_name: "Test 1") }
  let(:product2) { Y2Packager::Product.new(name: "test2", display_name: "Test 2") }
  subject { described_class.new([product1, product2]) }

  include_examples "CWM::RadioButtons"

  describe "#store" do
    before do
      allow(Yast::Pkg).to receive(:PkgApplReset)
      allow(Yast::Pkg).to receive(:PkgReset)
    end

    it "resets previous package configuration" do
      # mock selecting the first product
      allow(subject).to receive(:value).and_return("test1")
      allow(product1).to receive(:select)
      expect(Yast::Pkg).to receive(:PkgApplReset)
      expect(Yast::Pkg).to receive(:PkgReset)
      subject.store
    end

    it "selects the product to install" do
      # mock selecting the first product
      allow(subject).to receive(:value).and_return("test1")

      expect(product1).to receive(:select)
      expect(product2).to_not receive(:select)
      subject.store
    end
  end
end

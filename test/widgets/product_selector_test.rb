require_relative "../test_helper"

require "cwm/rspec"

require "installation/product"
require "installation/widgets/product_selector"

describe ::Installation::Widgets::ProductSelector do
  subject { described_class.new([Installation::Product.new("test", "Test")]) }

  include_examples "CWM::RadioButtons"
end

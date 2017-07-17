require_relative "../test_helper"

require "cwm/rspec"

require "installation/widgets/product_selector"

describe ::Installation::Widgets::ProductSelector do
  subject { described_class.new([["test", "Test"]]) }

  include_examples "CWM::RadioButtons"
end

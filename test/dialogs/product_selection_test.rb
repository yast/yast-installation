require_relative "../test_helper"

require "cwm/rspec"

require "installation/dialogs/product_selection"

describe ::Installation::Dialogs::ProductSelection do
  include_examples "CWM::Dialog"
end

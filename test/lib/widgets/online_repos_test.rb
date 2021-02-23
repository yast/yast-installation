#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/online_repos"
require "cwm/rspec"

describe Installation::Widgets::SelinuxPolicy do
  subject { described_class.new }

  include_examples "CWM::PushButton"
end

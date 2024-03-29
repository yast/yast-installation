#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/online_repos"
require "cwm/rspec"

describe Installation::Widgets::OnlineRepos do
  subject { described_class.new }

  before do
    allow(Yast::WFM).to receive(:CallFunction)
  end

  include_examples "CWM::PushButton"
end

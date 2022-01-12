#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/selinux_mode"
require "y2security/lsm/selinux"
require "cwm/rspec"

describe Installation::Widgets::SelinuxMode do
  subject { described_class.new(selinux_config) }
  let(:selinux_config) { Y2Security::LSM::Selinux.new }

  include_examples "CWM::ComboBox"
end

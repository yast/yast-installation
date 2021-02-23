#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/selinux_policy"
require "cwm/rspec"

describe Installation::Widgets::SelinuxPolicy do
  subject { described_class.new(Installation::SecuritySettings.create_instance) }

  include_examples "CWM::ComboBox"
end

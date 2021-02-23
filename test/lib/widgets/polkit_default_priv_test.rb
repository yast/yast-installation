#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/polkit_default_priv"
require "cwm/rspec"

describe Installation::Widgets::PolkitDefaultPriv do
  subject { described_class.new(Installation::SecuritySettings.create_instance) }

  include_examples "CWM::ComboBox"
end

require_relative "../../test_helper"

require "cwm/rspec"

require "installation/dialogs/security"
require "installation/security_settings"

describe ::Installation::Dialogs::Security do
  subject { described_class.new(::Installation::SecuritySettings.create_instance) }
  include_examples "CWM::Dialog"
end

require "yast"
require "cwm/widget"

# FIXME: these are mock only

# move this to: yast2-registration
module Widgets
  class RegistrationCode < CWM::InputField
    def initialize
      textdomain "FIXME"
    end

    def label
      _("Registration Code or SMT Server URL")
    end
  end
end


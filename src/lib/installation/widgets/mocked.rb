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
      _("Registration Code")
    end
  end
end

module Widgets
  class Overview < CWM::CustomWidget
    def contents
      VBox(
        Left(PushButton(Id(button_id), label)),
        Left(Label(" * foo")),
        Left(Label(" * bar"))
      )
    end

  private

    def button_id
      self.class.to_s
    end
  end

  class PartitioningOverview < Overview
    def initialize
      textdomain "FIXME"
    end

    def label
      _("Partitioning")
    end
  end

  class BootloaderOverview < Overview
    def initialize
      textdomain "FIXME"
    end

    def label
      _("Booting")
    end
  end
  class NetworkOverview < Overview
    def initialize
      textdomain "FIXME"
    end

    def label
      _("Network")
    end
  end
  class KdumpOverview < Overview
    def initialize
      textdomain "FIXME"
    end

    def label
      _("Kdump") # FIXME: spelling
    end
  end
end

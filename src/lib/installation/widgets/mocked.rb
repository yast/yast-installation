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

# move this to: stays in installation
module Widgets
  class SystemRole < CWM::ComboBox
    def initialize
      textdomain "FIXME"
    end

    def label
      _("System Role")
    end
    
    def items
      [
        ["Romeo",  _("Romeo")], # DUH, find the real ones
        ["Juliet", _("Juliet")]
      ]
    end
  end
end

# move this to: yast2-tune
module Widgets
  class SystemInformation < CWM::PushButton
    include Yast::Logger
    def initialize
      textdomain "tune"
    end

    def label
      _("System Information")
    end

    def handle
      Yast::WFM.CallFunction("inst_hwinfo", [])
      # doc?
      nil
    end
  end
end

module Widgets
  class Overview < CWM::CustomWidget
    def contents
      VBox(
        PushButton(Id(button_id), self.label),
        Label("* foo"),
        Label("* bar")
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
      _("Kdump")                # FIXME: spelling
    end
  end
end

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
        * items.map { |i| Left(Label(" * #{i}")) }
      )
    end

    def items
      ["foo", "bar"]
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
      textdomain "kdump"

      Yast.import "Kdump"
    end

    def label
      _("&Kdump")
    end

    def items
      Yast::Kdump.Summary
    end

    def handle(event)
      Yast::WFM.CallFunction("kdump_proposal", ["AskUser", {}])
      # FIXME: refresh the summary items
      nil
    end
  end
end

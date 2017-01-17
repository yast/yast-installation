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

module Widgets
  class Overview < CWM::CustomWidget
    def contents
      VBox(
        Left(PushButton(Id(button_id), label)),
        * items.map { |i| Left(Label(" * #{i}")) }
      )
    end

    def label
      d = Yast::WFM.CallFunction(proposal_client, ["Description", {}])
      d["menu_title"]
    end

    def items
      d = Yast::WFM.CallFunction(proposal_client,
                                 [
                                   "MakeProposal",
                                   {"simple_mode" => true}
                                 ])
      d["label_proposal"]
    end

    def handle(_event)
      Yast::WFM.CallFunction(proposal_client, ["AskUser", {}])
      :redraw
    end

  private

    def button_id
      self.class.to_s
    end
  end

  class PartitioningOverview < Overview
    def initialize
      textdomain "storage"
    end

    def proposal_client
      "partitions_proposal"
    end

    def label
      # FIXME: The storage subsystem is locked by an unknown app...
      if ENV["FAKE_STORAGE"]
        "&Partitioning"
      else
        super
      end
    end

    def items
      if ENV["FAKE_STORAGE"]
        ["Standard"]
      else
        super
      end
    end
  end

  class BootloaderOverview < Overview
    def initialize
      textdomain "bootloader"

      Yast.import "Bootloader"
    end

    def proposal_client
      "bootloader_proposal"
    end
  end

  class NetworkOverview < Overview
    def initialize
      textdomain "network"
      Yast.import "Lan"
    end

    def label
      _("&Network")
    end

    def items
      Yast::Lan.Summary("")
    end

    def handle(event)
      Yast::WFM.CallFunction("inst_lan", [{"skip_detection" => true}])
      # FIXME: refresh the summary items
      nil
    end

  end

  class KdumpOverview < Overview
    def initialize
      textdomain "kdump"

      Yast.import "Kdump"
    end

    def proposal_client
      "kdump_proposal"
    end
  end
end

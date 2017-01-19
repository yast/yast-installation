require "installation/proposal_client"

module Yast
  # Proposal client for Network configuration
  class NetworkProposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "UI"
      Yast.import "Lan"
      Yast.import "LanItems"

      textdomain "installation"
    end

  protected

    def description
      {
        "rich_text_title" => _("Network Configuration"),
        "menu_title"      => _("Network Configuration"),
        "id"              => "network"
      }
    end

    def make_proposal(_)
      {
        "preformatted_proposal" => Yast::Lan.Summary("summary"),
        "label_proposal"        => [Yast::LanItems.summary("one_line")]
      }
    end

    def ask_user(args)
      log.info "Launching network configuration"
      begin
        Yast::Wizard.OpenAcceptDialog

        result = Yast::WFM.CallFunction("inst_lan", [args.merge("skip_detection" => true)])

        log.info "Returning from the network configuration with: #{result}"
      ensure
        Yast::Wizard.CloseDialog
      end

      { "workflow_sequence" => result }
    end
  end
end

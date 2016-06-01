require "installation/proposal_client"
require "installation/ssh_importer"
require "installation/ssh_importer_presenter"

module Yast
  # Proposal client for SSH keys import
  class SshImportProposalClient < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "UI"
      textdomain "installation"
    end

  protected

    def description
      {
        # proposal part - bootloader label
        "rich_text_title" => _("Import SSH Host Keys and Configuration"),
        # menubutton entry
        "menu_title"      => _("&Import SSH Host Keys and Configuration"),
        "id"              => "ssh_import"
      }
    end

    def make_proposal(attrs)
      importer.reset if attrs["force_reset"]
      {
        "preformatted_proposal" => preformatted_proposal,
        "links"                 => ["ssh_import"]
      }
    end

    def importer
      ::Installation::SshImporter.instance
    end

    def preformatted_proposal
      ::Installation::SshImporterPresenter.new(
        ::Installation::SshImporter.instance).summary
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => param.fetch("has_next", false),
        "going_back"  => true
      }

      log.info "Asking user which SSH keys to import"
      begin
        Yast::Wizard.OpenAcceptDialog
        result = WFM.CallFunction("inst_ssh_import", [args])
      ensure
        Yast::Wizard.CloseDialog
      end
      log.info "Returning from ssh_import ask_user with #{result}"

      { "workflow_sequence" => result }
    end
  end
end

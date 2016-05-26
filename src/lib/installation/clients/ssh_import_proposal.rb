require "installation/proposal_client"
require "installation/ssh_importer"

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
        # empty string is returned in case of not previous installation to
        # avoid text link.
        "id"              => importer.configurations.empty? ? "" : "ssh_import"
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
      if importer.configurations.empty?
        return Yast::HTML.List([_("No previous Linux installation found")])
      end
      if importer.device.nil?
        res = _("No existing SSH host keys will be copied")
      else
        ssh_config = importer.configurations[importer.device]
        partition = ssh_config.system_name
        if importer.copy_config?
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          res = _("SSH host keys and configuration will be copied from %s") % partition
        else
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          res = _("SSH host keys will be copied from %s") % partition
        end
      end
      Yast::HTML.List([res])
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => param.fetch("has_next", false),
        "going_back"  => true
      }

      if importer.configurations.empty?
        result = :next
      else
        log.info "Asking user which SSH keys to import"
        begin
          Yast::Wizard.OpenAcceptDialog
          result = WFM.CallFunction("inst_ssh_import", [args])
        ensure
          Yast::Wizard.CloseDialog
        end
        log.info "Returning from ssh_import ask_user with #{result}"
      end
      { "workflow_sequence" => result }
    end
  end
end

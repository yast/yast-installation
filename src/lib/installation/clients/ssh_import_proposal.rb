require "installation/proposal_client"
require "installation/dialogs/ssh_import"
require "installation/ssh_config"

module Yast
  # Proposal client for bootloader configuration
  class SshImportProposalClient < ::Installation::ProposalClient
    include Yast::I18n

    @@calculated = false

    def initialize
      Yast.import "UI"
      textdomain "installation"
    end

  protected

    def description
      {
        # proposal part - bootloader label
        "rich_text_title" => _("Import SSH Configuration and Keys"),
        # menubutton entry
        "menu_title"      => _("&Import SSH Configuration and Keys"),
        "id"              => "ssh_import"
      }
    end

    def make_proposal(attrs)
      if !@@calculated || attrs["force_reset"]
        @@calculated = true
        set_default_values
      end
      update_ssh_configs
      {
        "preformatted_proposal" => preformatted_proposal,
        "links" => ["ssh_import"]
      }
    end

    # To ensure backwards compatibility, the default proposal is to copy all
    # the ssh keys in the most recently accessed config and to not copy any
    # additional config file
    def set_default_values
      @@device = default_ssh_config.device
      @@copy_config = false
    end

    # Syncs the status of SshConfig.all with the settings in the proposal
    #
    # It updates the #to_export flag for all the SSH keys and config files.
    def update_ssh_configs
      all_ssh_configs.each do |config|
        selected = config.device == @@device
        config.config_files.each { |f| f.to_export = (selected && @@copy_config) }
        config.keys.each { |k| k.to_export = selected }
      end
    end

    def default_ssh_config
      @default_ssh_config ||= all_ssh_configs.select(&:keys_atime).max_by(&:keys_atime)
    end

    def all_ssh_configs
      @all_ssh_configs ||= ::Installation::SshConfig.all
    end

    def preformatted_proposal
      if all_ssh_configs.empty?
        return _("No previous Linux installation found - not importing any SSH Key")
      end
      if @@device.nil?
        res = _("No existing SSH keys will be copied")
      else
        ssh_config = all_ssh_configs.detect { |c| c.device == @@device }
        partition = ssh_config.system_name
        if @@copy_config
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          res = _("SSH keys and configuration will be copied from %s") % partition
        else
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          res = _("SSH keys will be copied from %s") % partition
        end
      end
      res += " " + _("(<a href=%s>change</a>)") % '"ssh_import"'
      res
    end

    def ask_user(param)
      log.info "Asking user which SSH keys to import"
      user_input = Yast::SshImportDialog.new(@@device, @@copy_config).run
      if user_input
        log.info "SshImportDialog result: #{user_input}"
        @@device = user_input[:device]
        @@copy_config = user_input[:copy_config]
      end

      { "workflow_sequence" => :next }
    end
  end
end

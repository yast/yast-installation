require "yast"

require "installation/auto_client"
require "installation/ssh_importer"

Yast.import "Progress"
Yast.import "Mode"
Yast.import "Popup"

module Installation
  # AutoYaST client for ssh_import
  class SSHImportAutoClient < ::Installation::AutoClient
    class << self
      attr_accessor :changed
    end

    def run
      progress_orig = Yast::Progress.set(false)
      ret = super
      Yast::Progress.set(progress_orig)

      ret
    end

    # Importing data from the AutoYaST configuration module
    # AutoYaST data format:
    #
    # <ssh_import>
    #   <import config:type="boolean">true</import>
    #   <config config:type="boolean">true</config>
    #   <device>/dev/sda4</device>
    # </ssh_import>
    def import(data)
      if data["import"]
        log.info "Importing AutoYaST data: #{data}"
        ssh_importer.copy_config = data["config"] == true
        if data["device"] && !data["device"].empty?
          if ssh_importer.configurations.key?(data["device"])
            ssh_importer.device = data["device"]
          else
            Yast::Report.Warning(
              # TRANSLATORS: %s is the device name like /dev/sda0
              _("Device %s not found. Taking default entry.") %
              data["device"]
              )
          end
        end
      else
        ssh_importer.device = nil # do not copy ssh keys into the installed system
      end
      true
    end

    # Returns a human readable summary
    def summary
      message =
        if ssh_importer.configurations.empty?
          _("No previous Linux installation found - not importing any SSH Key")
        elsif ssh_importer.device.nil?
          _("No existing SSH host keys will be copied")
        else
          name = ssh_config.system_name
          if ssh_importer.copy_config?
            # TRANSLATORS: %s is the name of a Linux system found in the hard
            # disk, like 'openSUSE 13.2'
            _("SSH host keys and configuration will be copied from %s") % name
          else
            # TRANSLATORS: %s is the name of a Linux system found in the hard
            # disk, like 'openSUSE 13.2'
            _("SSH host keys will be copied from %s") % name
          end
        end
      "<UL>#{message}</UL>"
    end

    def modified?
      self.class.changed
    end

    def modified
      self.class.changed = true
    end

    def reset
      ssh_importer.reset
    end

    def change
      args = {
        "enable_back" => true,
        "enable_next" => false,
        "going_back"  => true
      }
      Yast::Wizard.OpenAcceptDialog
      WFM.CallFunction("inst_ssh_import", [args])
    ensure
      Yast::Wizard.CloseDialog
    end

    # Exporting data to the AutoYaST configuration module.
    # That's are default entries.
    def export
      ret = { "import" => true, "config" => false }
      # Device will not be set because it is optional and the
      # most-recently-accessed device (biggest keys_atime)
      # will be used for.
      # ret["device"] = device
      ret
    end

    # Writes the SSH keys from the selected device (and also other
    # configuration files if #copy_config? is true) in the target
    # filesystem
    def write
      if Mode.config
        Popup.Notify _("It makes no sense to write these settings to system.")
        true
      else
        ssh_importer.write(::Installation.destdir)
      end
    end

    def read
      # It is a user decision only. Not depending on system
      true
    end

  protected

    # Helper method to access to the SshImporter
    #
    # @return [::Installation::SshImporter] SSH importer
    def ssh_importer
      @ssh_importer ||= ::Installation::SshImporter.instance
    end

    # Helper method to access to SshConfig for the selected device
    #
    # @return [::Installation::SshConfig] SSH configuration
    def ssh_config
      # TODO: add a method #current_config to SshImporter (?)
      ssh_importer.device ? ssh_importer.configurations[ssh_importer.device] : nil
    end
  end
end

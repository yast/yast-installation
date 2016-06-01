require "yast"

require "installation/auto_client"
require "installation/ssh_importer"
require "installation/ssh_importer_presenter"

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
    #
    # @param data [Hash] AutoYaST specification.
    # @option data [Boolean] :import Import SSH keys
    # @option data [Boolean] :config Import SSH server configuration
    #   in addition to keys.
    # @option data [Boolean] :device Device to import the keys/configuration from.
    def import(data)
      if !data["import"]
        log.info("Do not import ssh keys/configuration")
        ssh_importer.device = nil # do not copy ssh keys into the installed system
        return true
      end

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
      true
    end

    # Returns a human readable summary
    #
    # @see ::Installation::SshImporterPresenter
    def summary
      ::Installation::SshImporterPresenter.new(ssh_importer).summary
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
      # If this module has been called and do not
      # depends on the installed system we would like to
      # have this section in the exported AutoYaST file
      # regardless if the entries have been changed nor not.
      modified

      begin
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
    end

    # Exporting data to the AutoYaST configuration module.
    # That's are default entries.
    def export
      ret = {}
      if Mode.config
        # Taking values from AutoYast configuration module
        if ssh_importer.device && !ssh_importer.device.empty?
          ret["import"] = true
          ret["config"] = ssh_importer.copy_config
          if !ssh_importer.device.empty? && ssh_importer.device != "default"
            ret["device"] = ssh_importer.device
          end
        else
          ret["import"] = false
          ret["config"] = false
        end
      else
        # Taking default values
        ret = { "import" => true, "config" => false }
        # Device will not be set because it is optional and the
        # most-recently-accessed device (biggest keys_atime)
        # will be used for.
        # ret["device"] = device
      end
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
  end
end

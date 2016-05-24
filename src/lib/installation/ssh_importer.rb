# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "installation/ssh_config"
Yast.import "Report"

module Installation
  # Entry point for the SSH keys importing functionality.
  #
  # This singleton class provides methods to hold a list of configurations found
  # in the hard disk and to copy its files to the target system
  class SshImporter
    include Singleton
    include Yast::I18n
    include Yast::Logger

    # @return [String] device name of the source filesystem (i.e. the
    # SshConfig to copy the keys from)
    attr_accessor :device
    # @return [boolean] whether to copy also the config files in addition to the
    # keys
    attr_accessor :copy_config
    # @return [Hash{String => SshConfig}] found configurations, indexed by device
    # name
    attr_reader :configurations

    alias_method :copy_config?, :copy_config

    def initialize
      @configurations = {}
      reset
    end

    # Set default settings (#device and #copy_config?)
    #
    # To ensure backwards compatibility, the default behavior is to copy the SSH
    # keys, but not other config files, from the most recently accessed config
    def reset
      set_device
      @copy_config = false
    end

    # Reads ssh keys and config files from a given root directory, stores the
    # information in #configurations and updates #device according to the
    # default behavior.
    #
    # Directories without keys in /etc/ssh are ignored.
    #
    # @param root_dir [String] Path where the original "/" is mounted
    # @param device [String] Name of the mounted device
    def add_config(root_dir, device)
      config = SshConfig.from_dir(root_dir)
      return if config.keys.empty?

      configurations[device] = config
      set_device
    end

    # Returns a human readable summary
    def summary
      if configurations.empty?
        return _("No previous Linux installation found - not importing any SSH Key")
      end
      if @device.nil?
        return _("No existing SSH host keys will be copied")
      else
        ssh_config = configurations[@device]
        partition = ssh_config.system_name
        if copy_config?
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          return _("SSH host keys and configuration will be copied from %s") % partition
        else
          # TRANSLATORS: %s is the name of a Linux system found in the hard
          # disk, like 'openSUSE 13.2'
          return _("SSH host keys will be copied from %s") % partition
        end
      end
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
      log.info "Importing AutoYaST data: #{data}"
      if data["import"]
        set_device # set default device
        @copy_config = data["config"] || false
        if data["device"] && !data["device"].empty?
          if configurations.has_key?( data["device"] )
            @device = data["device"]
          else
            Yast::Report.Warning(
              # TRANSLATORS: %s is the device name like /dev/sda0
              _("Device %s not found. Taking default entry.") %
              data["device"]
            )
          end
        end
      else
        @device = nil # do not copy ssh keys into the installed system
      end
    end

    # Exporting data to the AutoYaST configuration module
    def export
      ret = {}
      if device
        ret["import"] = true
      else
        ret["import"] = false
      end
      ret["config"] = copy_config
      # Device will not be set because it is optional and the
      # most-recently-accessed device (biggest keys_atime)
      # will be used for.
      # ret["device"] = device
      deep_copy(ret)
    end

    # Writes the SSH keys from the selected device (and also other configuration
    # files if #copy_config? is true) in the target filesystem
    #
    # @param root_dir [String] Path to use as "/" to locate the ssh directory
    def write(root_dir)
      return unless device
      configurations[device].write_files(
        root_dir,
        write_keys:         true,
        write_config_files: copy_config
      )
    end

  protected

    # Sets #device according to the logic implemented in the old
    # "copy_to_system" feature, to ensure backwards compatibility. That means
    # selecting the device which contains the most recently accessed (atime)
    # key file.
    #
    # For some background, see fate#300421, fate#305019, fate#319624
    def set_device
      if configurations.empty?
        @device = nil
      else
        with_atime = configurations.to_a.select { |_dev, config| config.keys_atime }
        if with_atime.empty?
          @device = configurations.keys.first
        else
          recent = with_atime.max_by { |_dev, config| config.keys_atime }
          @device = recent.first
        end
      end
    end
  end
end

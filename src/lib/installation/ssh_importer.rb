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

module Installation
  # Entry point for the SSH keys importing functionality.
  #
  # This singleton class provides methods to hold a list of configurations found
  # in the hard disk and to copy its files to the target system
  class SshImporter
    include Singleton

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

    # Writes the SSH keys from the selected device (and also other configuration
    # files if #copy_config? is true) in the target filesystem
    #
    # @param root_dir [String] Path to use as "/" to locate the ssh directory
    def write(root_dir)
      return unless device
      configurations[device].write_files(root_dir, write_config_files: copy_config)
    end

  protected

    def set_device
      if configurations.empty?
        @device = nil
      else
        with_atime = configurations.to_a.select { |dev, config| config.keys_atime }
        if with_atime.empty?
          @device = configurations.keys.first
        else
          recent = with_atime.max_by { |dev, config| config.keys_atime }
          @device = recent.first
        end
      end
    end
  end
end

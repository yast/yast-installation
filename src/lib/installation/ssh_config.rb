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

require "installation/ssh_key"
require "installation/ssh_config_file"
require "fileutils"

module Installation
  # Class that allows to memorize the list of SSH keys and config files found in
  # a filesystem (i.e. the content of the /etc/ssh directory)
  #
  # Used by the SSH keys importing functionality.
  class SshConfig
    # TODO: i18n
    DEFAULT_NAME = "Linux"

    class << self
      # Creates a new object with the information read from a filesystem
      #
      # @param root_dir [String] Path where the original "/" is mounted
      def from_dir(root_dir)
        config = SshConfig.new(name_for(root_dir))
        dir = ssh_dir(root_dir)
        config.read_files(dir)
        config
      end

      def ssh_dir(root_dir)
        File.join(root_dir, "etc", "ssh")
      end

    protected

      def os_release_file(root_dir)
        File.join(root_dir, "etc", "os-release")
      end

      # Find out the name for a previous Linux installation.
      # This uses /etc/os-release which is specified in
      # https://www.freedesktop.org/software/systemd/man/os-release.html
      #
      # @param mount_point [String] Path where the original "/" is mounted
      # @return [String] Speaking name of the Linux installation
      def name_for(mount_point)
        os_release = parse_ini_file(os_release_file(mount_point))
        name = os_release["PRETTY_NAME"]
        if name.empty? || name == DEFAULT_NAME
          name = os_release[NAME] || DEFAULT_NAME
          name += os_release[VERSION]
        end
        name
      rescue Errno::ENOENT # No /etc/os-release found
        DEFAULT_NAME
      end

      # Parse a simple .ini file and return the content in a hash.
      #
      # @param filename [String] Name of the file to parse
      # @return [Hash<String, String>] file content as hash
      #
      def parse_ini_file(filename)
        content = {}
        File.readlines(filename).each do |line|
          line = line.lstrip.chomp
          next if line.empty? || line.start_with?("#")
          (key, value) = line.split("=")
          value.gsub!(/^\s*"/, "")
          value.gsub!(/"\s*$/, "")
          content[key] = value
        end
        content
      end
    end

    # @return [String] name to help the user identify the configuration
    attr_accessor :system_name
    # @return [Array<SshKey>] keys found in the partition
    attr_accessor :keys
    # @return [Array<SshConfigFile>] configuration files found in the partition
    attr_accessor :config_files

    def initialize(system_name)
      self.system_name = system_name
      self.keys = []
      self.config_files = []
    end

    # Populates the list of keys and config files from a ssh configuration
    # directory
    #
    # @param dir [String] path of the SSH configuration directory
    def read_files(dir)
      filenames = Dir.glob("#{dir}/*")

      # Let's process keys first, pairs of files like "xyz" & "xyz.pub"
      pub_key_filenames = filenames.select { |f| f.end_with?(SshKey::PUBLIC_FILE_SUFFIX) }
      pub_key_filenames.each do |pub_file|
        # Remove the .pub suffix
        priv_file = pub_file.chomp(SshKey::PUBLIC_FILE_SUFFIX)
        add_key(priv_file)
        filenames.delete(pub_file)
        filenames.delete(priv_file)
      end

      filenames.each do |name|
        add_config_file(name)
      end
    end

    # Writes keys and/or configuration files to a filesystem
    #
    # @param root_dir [String] path where the target filesystem (/) is mounted
    # @param write_keys [Boolean] whether to copy the keys
    # @param write_config_files [Boolean] whether to copy the config files
    def write_files(root_dir, write_keys: true, write_config_files: true)
      dir = self.class.ssh_dir(root_dir)
      ::FileUtils.mkdir_p(dir)

      keys.each { |k| k.write_files(dir) } if write_keys
      config_files.each { |f| f.write(dir) } if write_config_files
    end

    # Access time of the most recently accessed SSH key.
    #
    # Needed to keep the default behavior backward compatible.
    #
    # @return [Time]
    def keys_atime
      keys.map(&:atime).max
    end

  protected

    def add_key(priv_filename)
      key = SshKey.new(File.basename(priv_filename))
      key.read_files(priv_filename)
      self.keys << key
    end

    def add_config_file(filename)
      file = SshConfigFile.new(File.basename(filename))
      file.read(filename)
      config_files << file
    end
  end
end

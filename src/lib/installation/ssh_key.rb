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

module Installation
  # Class that allows to memorize a particular SSH keys found in a partition.
  #
  # Used to implement the SSH keys importing functionality.
  class SshKey
    include Yast::Logger
    PUBLIC_FILE_SUFFIX = ".pub".freeze

    # @return [String] name for the user to identify the key
    attr_accessor :name
    # @return [Time] access time of the most recently accessed file
    attr_accessor :atime
    # @return [Array<Keyfile>] list of files associated to the key
    attr_accessor :files

    def initialize(name)
      @name = name
      @files = []
    end

    def read_files(priv_filename)
      add_file(priv_filename) if File.exist?(priv_filename)
      pub_filename = priv_filename + PUBLIC_FILE_SUFFIX
      add_file(pub_filename) if File.exist?(pub_filename)
    end

    def write_files(dir)
      log.info "Write SSH keys to #{dir}:\n#{self}"
      files.each do |file|
        path = File.join(dir, file.filename)
        IO.write(path, file.content)
        if file.filename =~ /^ssh_host_.*key$/
          # ssh deamon accepts only private keys with restricted
          # file permissions.
          log.info("Set permissions of #{file.filename} to 0o600")
          File.chmod(0o600, path)
        else
          # Taking already given permissions
          log.info("Set permissions of #{file.filename} to 0o#{file.permissions.to_s(8)}")
          File.chmod(file.permissions, path)
        end
      end
    end

    # Override to_s method for logging.
    def to_s
      "#{name}:\n" +
        files.collect { |file| "  #{file.filename}" }.join("\n")
    end

  protected

    KeyFile = Struct.new(:filename, :content, :permissions)

    def add_file(path)
      content = IO.read(path)
      permissions = File.stat(path).mode
      files << KeyFile.new(File.basename(path), content, permissions)
      atime = File.atime(path)
      self.atime = atime unless self.atime && self.atime > atime
    end
  end
end

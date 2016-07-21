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

require "fileutils"

module Installation
  # Class that allows to memorize a particular SSH config file found in a
  # partition.
  #
  # Used by the SSH configuration importing functionality.
  class SshConfigFile
    include Yast::Logger

    BACKUP_SUFFIX = ".yast.orig".freeze

    # @return [String] file name
    attr_accessor :name
    # @return [Time] access time of the original file
    attr_accessor :atime
    # @return [String] content of the file
    attr_accessor :content
    # @return [Fixmum] mode of the original file. @see File.chmod
    attr_accessor :permissions

    def initialize(name)
      @name = name
    end

    def read(path)
      self.content = IO.read(path)
      self.atime = File.atime(path)
      self.permissions = File.stat(path).mode
    end

    def write(dir)
      log.info "Write SSH config file #{dir} to #{name}"
      path = File.join(dir, name)
      backup(path)
      IO.write(path, content)
      File.chmod(permissions, path)
    end

    # Override to_s method for logging.
    def to_s
      name.to_s
    end

  protected

    def backup(filename)
      ::FileUtils.mv(filename, filename + BACKUP_SUFFIX) if File.exist?(filename)
    end
  end
end

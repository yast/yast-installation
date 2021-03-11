# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "yast2/execute"
require "pathname"
require "fileutils"

module Installation
  # This class cleans-up those files that are not actually needed for the
  # self-update mechanism. Starting in SLE-15-SP3, this class is not needed
  # anymore because the self-update procedure already removes them.
  #
  # The self-update mechanism involves the following pieces:
  #
  # * A set of squashfs files, one per package, that are located under
  #   /download (yast_001, yast_002, etc.). They contain the files of the
  #   updated packages.
  # * Each squashfs is mounted under /mounts (yast_0001, yast_0002, etc.).
  #   The original files are basically links to the updated ones (the `adddir`
  #   script of the inst-sys creates those links).
  #
  # This class umounts the directories whose files are not linked and removes
  # their associated squashfs files.
  #
  # See bsc#1182928 for further details.
  class SelfupdateCleaner
    include Yast::Logger

    MOUNTS_DIR = "mounts".freeze
    UPDATES_DIR = "download".freeze

    # Constructor
    #
    # @param root_dir [String,Pathname] Root directory
    def initialize(root_dir = "/")
      @root_dir = Pathname.new(root_dir)
      @mounts_dir = @root_dir.join(MOUNTS_DIR)
      @updates_dir = @root_dir.join(UPDATES_DIR)
    end

    # Runs the cleaning process
    #
    # @return [Array<String>] List of removed update IDs
    def run
      ids = unused_updates

      log.info "These #{ids.size} updates are not used and they will be removed: #{ids.sort}"
      ids.each { |id| umount_and_remove(id) }
      ids
    end

  private

    attr_reader :root_dir, :mounts_dir, :updates_dir

    # Returns the list of unused (not linked) updates
    #
    # @return [Array<String>]
    def unused_updates
      all_updates - used_updates
    end

    # Returns the list of used (linked) updates
    #
    # @return [Array<String>]
    # @raise CouldNotFindUsedUpdates
    def used_updates
      links = []
      root_dir.find do |path|
        next unless path.symlink?

        links << path.readlink if path.exist?
      end

      find_update_ids(links)
    end

    # Returns the list of all the updates
    #
    # @return [Array<String>]
    def all_updates
      find_update_ids(mounts_dir.glob("yast_*"))
    end

    # Extracts the update IDs for a list of paths
    #
    # @param paths [#to_a] Object that represents the list of paths
    # @return [Array<String>] List of update IDs
    def find_update_ids(paths)
      paths.to_a.each_with_object([]) do |path, all|
        update_id = path.to_s[mount_regexp, 1]
        all << update_id if update_id && !all.include?(update_id)
      end
    end

    # Returns the regexp to filter and extract update ids
    #
    # @return [Regexp]
    def mount_regexp
      /\A#{mounts_dir.join("yast_")}(\d+)/
    end

    # Umounts and removes an update with a given id
    #
    # @param update_id [String] Update ID
    def umount_and_remove(update_id)
      mounts_path = mounts_dir.join("yast_#{update_id}")
      system("umount #{mounts_path.to_s.shellescape}")
      ::FileUtils.rm_r(mounts_path)

      updated_path = updates_dir.join("yast_#{update_id[1..-1]}")
      ::FileUtils.rm(updated_path)
    end
  end
end

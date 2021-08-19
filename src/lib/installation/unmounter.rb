# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

module Installation
  # Class to handle unmounting all mounts from the given subtree on in the
  # right order.
  #
  # This uses /proc/mounts by default to find active mounts, but for
  # testability, it can also be fed from other files or line by line. It stores
  # all necessary unmount actions so they can be executed all at once, and they
  # can also be inspected without the execute step. This is intended for
  # logging, debugging and testing.
  #
  # This relies on /proc/mounts already containing the entries in canonical
  # order (which it always does), i.e. in the mount hierarchy from top to
  # bottom. If you add entries manually, make sure to maintain that order.
  #
  class Unmounter
    include Yast::Logger
    # @return [Array<Mount>] Relevant mounts to unmount
    attr_reader :mounts
    # @return [Array<Mount>] Ignored mount
    attr_reader :ignored_mounts

    # Helper class to represent one mount, i.e. one entry in /proc/mounts.
    class Mount
      attr_reader :device, :mount_path, :fs_type, :mount_opt

      def initialize(device, mount_path, fs_type = "", mount_opt = "")
        @device = device
        @mount_path = mount_path
        @fs_type = fs_type
        @mount_opt = mount_opt
      end

      # Check if this is a mount for a btrfs.
      # @return [Boolean] true if btrfs, false if not
      #
      def btrfs?
        return false if @fs_type.nil?

        @fs_type.downcase == "btrfs"
      end

      # Format this mount as a string for logging.
      #
      def to_s
        "<Mount #{@device} -> #{@mount_path} type #{@fs_type}>"
      end
    end

    # Unmounter constructor.
    #
    # @param mnt_prefix [String] Prefix which paths should be unmounted.
    #
    # @param mounts_file_name [String] what to use instead of /proc/mounts.
    #   Use an empty string (not nil!) to not read anything at all yet
    #   (but in that case, use read_mounts_file or add_mount later).
    #
    def initialize(mnt_prefix, mounts_file_name = nil)
      @mnt_prefix = mnt_prefix || "/mnt"
      mounts_file_name ||= "/proc/mounts"
      clear
      read_mounts_file(mounts_file_name) unless mounts_file_name.empty?
    end

    # Clear all prevous content.
    def clear
      @mounts = []
      @ignored_mounts = []
    end

    # Read a mounts file like /proc/mounts and add the relevant entries to the
    # mounts stored in this class.
    #
    def read_mounts_file(file_name)
      log.info("Reading file #{file_name}")
      open(file_name).each { |line| add_mount(line) }
    end

    # Parse one entry of /proc/mounts and add it to @mounts
    # if it meets the criteria (mount prefix, no btrfs subvolume)
    #
    # @param line [String] one line of /proc/mounts
    # @return [Mount,nil] parsed mount if relevant
    #
    def add_mount(line)
      mount = parse_mount(line)
      return nil if mount.nil? # Empty or comment

      if ignore?(mount)
        @ignored_mounts << mount
        return nil
      end

      log.info("Adding #{mount}")
      @mounts << mount
      mount
    end

    # Check if a mount should be ignored, i.e. if the path either doesn't start
    # with the mount prefix (usually "/mnt") or if it is a btrfs subvolume.
    #
    # A subvolume cannot be unmounted while its parent main volume is still mounted; that will result in a
    #
    # @return [Boolean] ignore
    #
    def ignore?(mount)
      return true unless mount.mount_path.start_with?(@mnt_prefix)

      if mount.btrfs? && mount_for_device(mount.device)
        # We already have a mount for a Btrfs on this device,
        # so any more mount for that device must be a subvolume.
        #
        # Notice that this relies on /proc/mounts being in the correct order:
        # Btrfs main mount first, all its subvolumes after that.
        log.info("-- Ignoring btrfs subvolume #{mount}")
        return true
      end

      false # don't ignore
    end

    # Parse one entry of /proc/mounts.
    #
    # @param line [String] one line of /proc/mounts
    # @return [Mount,nil] parsed mount
    #
    def parse_mount(line)
      line.strip!
      return nil if line.empty? || line.start_with?("#")

      (device, mount_path, fs_type, mount_opt) = line.split
      return Mount.new(device, mount_path, fs_type, mount_opt)
    end

    # Return the mount for a specified device or nil if there is none.
    #
    # @param device [String]
    # @return [Mount,nil] Matching mount
    #
    def mount_for_device(device)
      @mounts.find { |mount| mount.device == device }
    end

    # Return the paths to be unmounted in the correct unmount order.
    #
    # This makes use of the fact that /proc/mounts is already sorted in
    # canonical order, i.e. from toplevel mount points to lower level ones.
    #
    # @return [Array<String>] paths
    #
    def unmount_paths
      paths = @mounts.map(&:mount_path)
      paths.reverse
    end

    # Return the paths that were ignored (in the order of /proc/mounts).
    # This is mostly useful for debugging and testing.
    #
    # @return [Array<String>] paths
    #
    def ignored_paths
      @ignored_mounts.map(&:mount_path)
    end

    # Actually execute all the pending unmount operations.
    #
    def execute
      unmount_paths.each do |path|
        log.info("Unmounting #{path}")
        Yast::Execute.locally!("umount", path)
      end
    end
  end
end


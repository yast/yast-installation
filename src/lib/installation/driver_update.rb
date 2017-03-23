# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
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
require "pathname"

module Installation
  # Represents a driver update.
  #
  # This class will handle driver updates which are applied yet.
  # The main purpose is to re-apply them after the installer's
  # self-update has been performed.
  #
  # At this point, two kinds of driver updates are considered:
  #
  # * Driver Update Disks (DUD): a directory containing different
  #   subdirectories, one of them called inst-sys.
  # * Packages: are stored in a squashed filesystem which is mounted
  #   in /mounts directory.
  #
  class DriverUpdate
    include Yast::Logger

    class CouldNotBeApplied < StandardError; end
    class PreScriptFailed < StandardError; end
    class NotFound < StandardError; end

    # @return [Pathname] Path to the driver update.
    attr_reader :path

    # @return [Symbol] Kind of driver update (:dud or :archive).
    attr_reader :kind

    # @return [Pathname] Path to the instsys path of the driver
    #                    update.
    attr_reader :instsys_path

    class << self
      # Find driver updates in a given set of directories
      #
      # @param update_dirs [Array<Pathname>,Pathname] Directories to search for driver updates
      # @return [Array<DriverUpdate>] Found driver updates
      def find(update_dirs)
        dirs = Array(update_dirs)
        log.info("Searching for Driver Updates at #{dirs.map(&:to_s)}")
        globs = dirs.map { |d| d.join("dud_*") }
        Pathname.glob(globs).map do |path|
          log.info("Found a Driver Update at #{path}")
          new(path)
        end
      end
    end

    # Constructor
    #
    # @param path [Pathname] Path to driver update
    #
    # @raise NotFound
    def initialize(path)
      @path = path
      if !path.exist?
        log.error("Driver Update not found at #{path}")
        raise NotFound
      end
      @kind = path.file? ? :archive : :dud
      @instsys_path = send("#{@kind}_instsys_path")
    end

    # Command to apply the DUD disk to inst-sys
    APPLY_CMD = "/etc/adddir %<source>s /".freeze # openSUSE/installation-images

    # Add files/directories to the inst-sys
    #
    # @see APPLY_CMD
    #
    # @raise CouldNotBeApplied
    def apply
      return false if instsys_path.nil? || !instsys_path.exist?
      cmd = format(APPLY_CMD, source: instsys_path)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Applying update at #{path} (#{cmd}): #{out}")
      raise CouldNotBeApplied unless out["exit"].zero?
    end

  private

    # LOSETUP command
    LOSETUP_CMD = "/sbin/losetup".freeze

    # Returns the instsys_path for updates of type :archive
    #
    # Packages updates have a loopback device attached and are mounted.
    # So this method searches mount point for the attached device.
    #
    # @return [Pathname] Update's mountpoint
    def archive_instsys_path
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), LOSETUP_CMD)
      log.info("Reading loopback devices: #{out}")
      regexp = %r{(/dev/loop\d+)[^\n]+#{path.to_s}\n}
      lodevice = out["stdout"][regexp, 1]
      mount = Yast::SCR.Read(Yast::Path.new(".proc.mounts")).find { |m| m["spec"] == lodevice }
      if mount.nil?
        log.warn("Driver Update at #{path} is not mounted")
      else
        log.info("Driver Update mount point for #{path} is #{mount}")
        Pathname.new(mount["file"])
      end
    end

    # Returns the instsys_path for updates of type :dud
    #
    # Driver Update Disks are uncompressed and available somewhere.
    #
    # @return [Pathname] Path to the inst-sys part of the driver update
    def dud_instsys_path
      path.join("inst-sys")
    end
  end
end

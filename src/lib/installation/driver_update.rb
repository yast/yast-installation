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
  # Represents a driver update disk (DUD)
  #
  # The DUD will be fetched from a given URL.
  class DriverUpdate
    include Yast::Logger

    class CouldNotBeApplied < StandardError; end
    class PreScriptFailed < StandardError; end

    # Command to apply the DUD disk to inst-sys
    APPLY_CMD = "/etc/adddir %<source>s/inst-sys /" # openSUSE/installation-images

    attr_reader :path

    class << self
      # Find driver updates in a given directory
      #
      # A directory with a `dud.config` file will be considered a driver
      # update.
      #
      # @param dir [Pathname] Directory to search for driver updates
      # @return [Array<DriverUpdate>] Found driver updates
      def find(dir)
        log.info("Searching for Driver Updates at #{dir}")
        Pathname.glob("#{dir}/*/dud.config").map do |path|
          dud_dir = path.dirname
          log.info("Found a Driver Update at #{dud_dir}")
          new(dud_dir)
        end
      end
    end

    # Constructor
    #
    # @param path [Pathname] Path to driver update
    def initialize(path)
      @path = path
    end

    # Apply the DUD to inst-sys
    #
    # @see #adddir
    # @see #run_update_pre
    def apply(pre: false)
      adddir
      run_update_pre if pre
    end

    # Add files/directories to the inst-sys
    #
    # @see APPLY_CMD
    #
    # @raise CouldNotBeApplied
    def adddir
      cmd = format(APPLY_CMD, source: path)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Applying update at #{path} (#{cmd}): #{out}")
      raise CouldNotBeApplied unless out["exit"].zero?
    end

    # Run update.pre script
    #
    # @return [Boolean] true if execution was successful; false if
    #                   update script didn't exist.
    #
    # @raise DriverUpdate::PreScriptFailed
    def run_update_pre
      update_pre_path = path.join("install", "update.pre")
      return false unless update_pre_path.exist? && update_pre_path.executable?
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), update_pre_path.to_s)
      log.info("update.pre script at #{update_pre_path} was executed: #{out}")
      raise PreScriptFailed unless out["exit"].zero?
      true
    end
  end
end

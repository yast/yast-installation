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

require "pathname"
require "installation/driver_update"

module Installation
  # This class takes care of managing installer updates
  #
  # Installer updates are distributed as Driver Update Disks that are downloaded
  # from a remote location (only HTTP and HTTPS are supported at this time).
  # This class tries to offer a really simple API to get updates and apply them
  # to inst-sys.
  #
  # @example Applying one driver update
  #   manager = UpdatesManager.new
  #   manager.add_update(URI("http://update.opensuse.org/sles12.dud"))
  #   manager.add_update(URI("http://example.net/example.dud"))
  #   manager.fetch_all
  #   manager.apply_all
  #
  # @example Applying multiple driver updates
  #   manager = UpdatesManager.new
  #   manager.add_update(URI("http://update.opensuse.org/sles12.dud"))
  #   manager.fetch_all
  #   manager.apply_all
  class UpdatesManager
    attr_reader :target, :updates

    # Constructor
    #
    # @param target [Pathname] Directory to copy updates to.
    def initialize(target = Pathname.new("/update"))
      @target = target
      @updates = []
    end

    # Add an update to the updates pool
    #
    # @param uri [URI]                               URI where the update (DUD) lives
    # @return    [Array<Installation::DriverUpdate>] List of updates
    #
    # @see Installation::DriverUpdate
    def add_update(uri)
      new_update = Installation::DriverUpdate.new(uri)
      dir = target.join(format("%03d", next_update))
      new_update.fetch(dir)
      @updates << new_update
    rescue Installation::DriverUpdate::NotFound
      false
    end

    # Fetches all updates in the pool
    def fetch_all
      shift = next_update
      updates.each_with_index do |update, idx|
        update.fetch(target.join("00#{idx + shift}"))
      end
    end

    # Applies all updates in the pool
    def apply_all
      updates.each(&:apply)
    end

    # Determines whether the updates to apply are signed
    def all_signed?
      updates.all?(&:signed?)
    end

    private

    # Find the number for the next update to be deployed
    def next_update
      files = Pathname.glob(target.join("*")).map(&:basename)
      updates = files.map(&:to_s).grep(/\A\d+\Z/)
      updates.empty? ? 0 : updates.map(&:to_i).max + 1
    end
  end
end

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
require "installation/update_repository"

module Installation
  # This class takes care of managing installer updates
  #
  # Installer updates are distributed as rpm-md repositories. This class tries
  # to offer a really simple API to get updates and apply them to inst-sys.
  #
  # @example Applying updates from one repository
  #   manager = UpdatesManager.new
  #   manager.add_repository(URI("http://update.opensuse.org/42.1"))
  #   manager.apply_all
  #
  # @example Applying updates from multiple repositories
  #   manager = UpdatesManager.new
  #   manager.add_repository(URI("http://update.opensuse.org/42.1"))
  #   manager.add_repository(URI("http://example.net/leap"))
  #   manager.apply_all
  class UpdatesManager
    include Yast::Logger

    # @return [Array<UpdateRepository>] Repositories containing updates
    attr_reader :repositories

    # @return [Array<DriverUpdate>] Driver updates found in inst-sys
    attr_reader :driver_updates

    # The URL was found but a valid repo is not there.
    class ValidRepoNotFound < StandardError; end

    # The update could not be fetched (missing packages, broken
    # repository, etc.).
    class CouldNotFetchUpdateFromRepo < StandardError; end

    # Repo is unreachable (name solving issues, etc.).
    class CouldNotProbeRepo < StandardError; end

    DRIVER_UPDATES_PATH = Pathname("/update")

    # Constructor
    #
    # At instantiation time, this class looks for existin driver
    # updates in the given `duds_path`.
    #
    # @param duds_path [Pathname] Path where driver updates are supposed to live
    def initialize(duds_path = DRIVER_UPDATES_PATH)
      @repositories = []
      @driver_updates = Installation::DriverUpdate.find(duds_path)
    end

    # Add an update repository
    #
    # Most of exceptions coming from Installation::UpdateRepository are
    # catched, except those that has something to do with applying
    # the update itself (mounting or adding files to inst-sys). Check
    # Installation::UpdateRepository::CouldNotMountUpdate and
    # Installation::UpdateRepository::CouldNotBeApplied for more
    # information.
    #
    # @param uri [URI] URI where the repository lives
    # @return [Array<UpdateRepository] Array of repositories to be applied
    #
    # @see Installation::UpdateRepository
    def add_repository(uri)
      new_repository = Installation::UpdateRepository.new(uri)
      new_repository.fetch
      @repositories << new_repository
    rescue Installation::UpdateRepository::ValidRepoNotFound
      log.warn("Update repository at #{uri} could not be found")
      raise ValidRepoNotFound
    rescue Installation::UpdateRepository::FetchError
      log.error("Update repository at #{uri} was found but update could not be fetched")
      raise CouldNotFetchUpdateFromRepo
    rescue Installation::UpdateRepository::CouldNotProbeRepo
      log.error("Update repository at #{uri} could not be read")
      raise CouldNotProbeRepo
    end

    # Applies all the updates
    #
    # It delegates the responsability of updating the inst-sys to
    # added repositories and driver updates.
    #
    # @see Installation::UpdateRepository#apply
    # @see Installation::DriverUpdate#apply
    # @see #repositories
    def apply_all
      (repositories + driver_updates).each(&:apply)
      repositories.each(&:cleanup)
    end
  end
end

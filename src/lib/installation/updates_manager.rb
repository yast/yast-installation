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

    attr_reader :repositories, :driver_updates

    DRIVER_UPDATES_PATH = Pathname("/update")

    # Constructor
    def initialize(duds_path = DRIVER_UPDATES_PATH)
      @repositories = []
      @driver_updates = Installation::DriverUpdate.find(duds_path)
    end

    # Add an update repository
    #
    # @param uri [URI] URI where the repository lives
    # @return [Symbol] :ok if the repository was added;
    #                  :not_found if it wasn't found a valid repository;
    #                  :error if some error happened when fetching the update.
    #
    # @see Installation::UpdateRepository
    def add_repository(uri)
      new_repository = Installation::UpdateRepository.new(uri)
      new_repository.fetch
      @repositories << new_repository
      :ok
    rescue Installation::UpdateRepository::ValidRepoNotFound
      log.warn("Update repository at #{uri} could not be found")
      :not_found
    rescue Installation::UpdateRepository::CouldNotProbeRepo,
           Installation::UpdateRepository::CouldNotRefreshRepo
      log.error("Update repository at #{uri} was found but update could not be fetched")
      :error
    end

    # Applies all the updates
    #
    # It delegates the responsability of updating the inst-sys to
    # added repositories and driver updates.
    #
    # @see Installation::UpdateRepository#apply
    # @see #repositories
    def apply_all
      repositories.each(&:apply)
      driver_updates.each(&:apply)
      repositories.each(&:cleanup)
    end
  end
end

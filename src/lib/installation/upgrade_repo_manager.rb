# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC
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

require "y2packager/original_repository_setup"
require "y2packager/repository"
require "y2packager/service"

Yast.import "Pkg"

module Installation
  # This class takes care of managing the old repositories and services
  # during upgrade. It takes care of modifying the old repositories
  # and using them in the new upgraded system.
  class UpgradeRepoManager
    include Yast::Logger
    extend Yast::Logger

    # @return [Array<Y2Packager::Repository>] The old repositories
    attr_reader :repositories
    # @return [Array<Y2Packager::Repository>] The old services
    attr_reader :services

    # Constructor
    #
    # @param old_repositories [Array<Y2Packager::Repository>] the old
    #   repositories which should be managed
    # @param old_services [Array<Y2Packager::Service>] the old
    #   services which should be managed
    def initialize(old_repositories, old_services)
      @repositories = old_repositories
      @services = old_services
      @new_urls = {}
      # by default remove all repositories
      @status_map = Hash[repositories.map { |r| [r, :removed] }]
    end

    def self.create_from_old_repositories
      # Find the current repositories for the old ones,
      # the repositories might have been changed during the upgrade
      # workflow by other clients, this ensures we use the current data.
      current_repos = Y2Packager::Repository.all
      stored_repos = Y2Packager::OriginalRepositorySetup.instance.repositories
      stored_repo_aliases = stored_repos.map(&:repo_alias)
      reg_urls = registration_urls

      old_repos = current_repos.select do |r|
        stored_repo_aliases.include?(r.repo_alias) &&
          !reg_urls.include?(base_url(r.raw_url.uri))
      end

      current_services = Y2Packager::Service.all
      stored_services = Y2Packager::OriginalRepositorySetup.instance.services
      stored_service_aliases = stored_services.map(&:alias)
      old_services = current_services.select { |s| stored_service_aliases.include?(s.alias) }

      # sort the repositories by name
      new(old_repos.sort_by(&:name), old_services)
    end

    # Return the configured status of a repository.
    # @param  repo [Y2Packager::Repository] the repository
    # @return [Symbol, nil] `:removed`, `:enabled` or `:disabled` symbol,
    #    `nil` if the repository is not known
    def repo_status(repo)
      status_map[repo]
    end

    # Return the repository URL, if it was changed by the user than the new
    # URL is returned.
    #
    # @param repo [Y2Packager::Repository] The queried repository
    # @return [String] The URL
    def repo_url(repo)
      new_urls[repo] || repo.url.to_s
    end

    # Toggle the repository status.
    # It cycles the repository status in this order:
    # Removed->Enabled->Disabled->Removed->Enabled->Disabled->...
    #
    # @param  repo [Y2Packager::Repository] the repository
    # @return [Symbol, nil] `:removed`, `:enabled` or `:disabled` symbol,
    #    `nil` if the repository is not known
    def toggle_repo_status(repo)
      case repo_status(repo)
      when :enabled
        status_map[repo] = :disabled
      when :disabled
        status_map[repo] = :removed
      when :removed
        status_map[repo] = :enabled
      end
    end

    # Change the URL of a repository.
    #
    # @param repo [Y2Packager::Repository] The repository
    # @param url [String] Its new URL
    def change_url(repo, url)
      new_urls[repo] = url if repo.raw_url.to_s != url
    end

    # Activate the changes. This will enable/disable the repositories,
    # set the new URLs and remove old services without saving the changes.
    # To make the changes permanent (saved to disk) call `YaST::Pkg.SourceSaveAll`
    # after calling this method.
    def activate_changes
      update_urls
      process_repos
      remove_services
    end

  private

    # remove the old services
    def remove_services
      log.info("Old services to remove: #{services.map(&:alias).inspect}")
      services.each do |s|
        log.info("Removing old service #{s.alias}...")
        Yast::Pkg.ServiceDelete(s.alias)
      end
    end

    # @return [Hash<Y2Packager::Repository,Symbol>] Maps the repositories
    # to the new requested state.
    attr_reader :status_map

    # @return [Hash<Y2Packager::Repository,String>] Maps the repositories
    # to the new requested URLs.
    attr_reader :new_urls

    # change the status of the repositories to the requested states
    def process_repos
      status_map.each do |repo, status|
        case status
        when :enabled
          log.info("Enabling #{repo.repo_alias.inspect} ...")
          repo.enable!
        when :disabled
          log.info("Disabling #{repo.repo_alias.inspect} ...")
          repo.disable!
        when :removed
          log.info("Removing #{repo.repo_alias.inspect} ...")
          repo.delete!
        end
      end
    end

    # update the repository URLs to the requested values
    def update_urls
      new_urls.each do |repo, url|
        repo.url = url
      end
    end

    # Collect the repository URLs for all registered products and addons,
    # If the system is not registered or the yast2-registration package is not
    # installed then it return an empty list.
    #
    # @return [Array<URI>] list of simplified URLs
    # @see .base_url
    def self.registration_urls
      require "registration/registration"
      require "registration/registration_ui"
      require "registration/url_helpers"

      return [] unless Registration::Registration.is_registered?

      registration = Registration::Registration.new(Registration::UrlHelpers.registration_url)
      registration_ui = Registration::RegistrationUI.new(registration)
      activations = registration_ui.activated_products

      activations.map(&:repositories).flatten.map { |repo| base_url(repo["url"]) }
    rescue LoadError
      # the registration package is not available in the openSUSE installer
      # or during RPM build
      log.info("Registration package not available")
      []
    end

    # Remove some URL parts to allow less strict comparison:
    # - remove the query parameter, the locally saved SCC repositories have
    #   an unique hash attached as a query parameter, the activated products
    #   result does not contain that
    # - ignore the trailing slash, it is not important for comparing repositories
    #
    # @param repo_url [String, URI] the input URL
    # @return [URI] simplified URL
    def self.base_url(repo_url)
      uri = repo_url.is_a?(URI) ? repo_url.dup : URI(repo_url)
      uri.query = nil
      # do NOT use the bang method here (delete_suffix!), it would modify
      # the original URL although the .dup is used above!
      uri.path = uri.path.delete_suffix("/")
      uri
    end

    private_class_method :registration_urls, :base_url
  end
end

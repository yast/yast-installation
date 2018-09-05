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

require "installation/updates_manager"
require "installation/update_repositories_finder"
require "installation/selfupdate_addon_repo"
require "uri"
require "yaml"

module Yast
  class InstUpdateInstaller
    include Yast::Logger
    include Yast::I18n

    UPDATED_FLAG_FILENAME = "installer_updated".freeze
    PROFILE_FORBIDDEN_SCHEMES = ["label"].freeze
    REGISTRATION_DATA_PATH = "/var/lib/YaST2/inst_update_installer.yaml".freeze

    Yast.import "Pkg"
    Yast.import "Packages"
    Yast.import "PackageCallbacks"
    Yast.import "InstURL"
    Yast.import "Language"
    Yast.import "GetInstArgs"
    Yast.import "Directory"
    Yast.import "Installation"
    Yast.import "ProductFeatures"
    Yast.import "Label"
    Yast.import "Linuxrc"
    Yast.import "Popup"
    Yast.import "Report"
    Yast.import "NetworkService"
    Yast.import "Mode"
    Yast.import "Profile"
    Yast.import "ProfileLocation"
    Yast.import "AutoinstConfig"
    Yast.import "AutoinstGeneral"

    def main
      textdomain "installation"

      return :back if GetInstArgs.going_back

      require_registration_libraries

      if Installation.restarting?
        load_registration_url
        Installation.finish_restarting!
      end

      # shortcut - already updated, disabled via boot option or network not running
      if installer_updated? || disabled_in_linuxrc? || !NetworkService.isNetworkRunning
        log.info "Self update not needed, skipping"
        return :next
      end

      if Mode.auto
        process_profile
        return :next if disabled_in_profile?
      end

      initialize_progress
      initialize_packager

      # self-update not possible, the repo URL is not defined
      return :next unless try_to_update?

      log.info("Trying installer update")
      installer_updated = update_installer

      store_registration_url # Registration URL could be set by UpdateRepositoriesFinder

      if installer_updated
        # Indicates that the installer was updated.
        ::FileUtils.touch(update_flag_file)
        Yast::Progress.NextStage
        Installation.restart!
      else
        :next
      end
    ensure
      finish_packager
      finish_progress
    end

    # Tries to update the installer
    #
    # It also shows feedback to the user in case of error.
    #
    # Errors handling:
    #
    # * A repository is not found: warn the user if she/he is using
    #   a custom URL.
    # * Could not fetch update from repository: report the user about
    #   this error.
    # * Repository could not be probed: suggest checking network
    #   configuration if URL is remote.
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      updated = update_repositories.map { |u| add_repository(u) }.any?

      if updated
        # copy the addon packages before applying the updates to inst-sys,
        # #apply_all removes the repositories!
        Yast::Progress.NextStage
        copy_addon_packages
        log.info("Applying installer updates")
        Yast::Progress.NextStage
        updates_manager.apply_all
      end
      updated
    end

    # TODO: convenience method just for testing (to be removed)
    def update_repositories_finder
      @update_repositories_finder ||= ::Installation::UpdateRepositoriesFinder.new
    end

  protected

    # Instantiates an UpdatesManager to be used by the client
    #
    # The manager is 'memoized'.
    #
    # @return [UpdatesManager] Updates manager to be used by the client
    def updates_manager
      @updates_manager ||= ::Installation::UpdatesManager.new
    end

    # Determines whether self-update feature is enabled
    #
    # * Check whether is disabled via Linuxrc
    # * Otherwise, it's considered as enabled if some URL is defined.
    #
    # @return [Boolean] True if it's enabled; false otherwise.
    def self_update_enabled?
      if disabled_in_linuxrc?
        log.info("self-update was disabled through Linuxrc")
        false
      else
        !update_repositories.empty?
      end
    end

    # disabled via Linuxrc ?
    # @return [Boolean] true if self update has been disabled by "self_update=0"
    #   boot option
    def disabled_in_linuxrc?
      Linuxrc.InstallInf("SelfUpdate") == "0"
    end

    # Determines whether self-update feature is disabled via AutoYaST profile
    #
    # @return [Boolean] true if self update has been disabled by AutoYaST profile
    def disabled_in_profile?
      profile = Yast::Profile.current
      !profile.fetch("general", {}).fetch("self_update", true)
    end

    # Return the self-update URLs
    #
    # @return [Array<URI>] self-update URLs
    #
    # @see #default_self_update_url
    # @see #custom_self_update_url
    def update_repositories
      return @update_repositories if @update_repositories
      @update_repositories = update_repositories_finder.updates
      log.info("self-update repositories are #{@update_repositories.inspect}")
      @update_repositories

    rescue ::Installation::RegistrationURLError
      Report.Error(_("The registration URL provided is not valid.\n" \
                  "Skipping installer update.\n"))
      @update_repositories = []
    end

    # Return the custom self-update URL
    #
    # A custom URL can be specified via Linuxrc or in an AutoYaST profile.
    # Only 1 custom self-update URL can be specified.
    #
    # @return [URI] self-update URL
    # @see #self_update_url_from_linuxrc
    # @see #self_update_url_from_profile
    def custom_self_update_url
      @custom_self_update_url ||= self_update_url_from_linuxrc || self_update_url_from_profile
    end

    # Check if installer was updated
    #
    # It checks if a file UPDATED_FLAG_FILENAME exists in Directory.vardir
    #
    # @return [Boolean] true if it exists; false otherwise.
    def installer_updated?
      if File.exist?(update_flag_file)
        log.info("#{update_flag_file} exists")
        true
      else
        log.info("#{update_flag_file} does not exist")
        false
      end
    end

    # Returns the path to the "update flag file"
    #
    # @return [String] Path to the "update flag file"
    #
    # @see #update_installer
    def update_flag_file
      File.join(Directory.vardir, UPDATED_FLAG_FILENAME)
    end

    # Add a repository to the updates manager
    #
    # @param repo [UpdateRepository] Update repository to add
    # @return [Boolean] true if the repository was added; false otherwise.
    def add_repository(repo)
      log.info("Adding update from #{repo.inspect}")
      updates_manager.add_repository(repo.uri)

    rescue ::Installation::UpdatesManager::NotValidRepo
      if repo.user_defined?
        # TRANSLATORS: %s is an URL
        Report.Error(format(_("A valid update could not be found at\n%s.\n\n"), repo.uri))
      end
      false

    rescue ::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo
      if repo.user_defined?
        # TRANSLATORS: %s is an URL
        Report.Error(format(_("Could not fetch update from\n%s.\n\n"), repo.uri))
      end
      false

    rescue ::Installation::UpdatesManager::CouldNotProbeRepo
      return false unless repo.user_defined?
      msg = could_not_probe_repo_msg(repo.uri)
      if Mode.auto
        Report.Warning(msg)
      elsif repo.remote? && configure_network?(msg)
        retry
      end
      false
    end

    # Launch the network configuration client on users' demand
    #
    # Ask the user about checking network configuration. If she/he accepts,
    # the `inst_lan` client will be launched.
    #
    # @param reason [String] reason why user want to check his network configuration
    # @return [Boolean] true if the network configuration client was launched;
    #                   false if the network is not configured.
    def configure_network?(reason)
      msg = reason + _("\nWould you like to check your network configuration\n" \
        "and try installing the updates again?")

      if Popup.YesNo(msg)
        Yast::WFM.CallFunction("inst_lan", [{ "skip_detection" => true }])
        true
      else
        false
      end
    end

    # Check whether the update should be performed
    #
    # The update should be performed when these requeriments are met:
    #
    # * Network is up.
    # * Installer is not updated yet.
    # * Self-update feature is enabled and the repository URL is defined
    #
    # @return [Boolean] true if the update should be performed; false otherwise.
    #
    # @see #installer_updated?
    # @see #self_update_enabled?
    # @see NetworkService.isNetworkRunning
    def try_to_update?
      NetworkService.isNetworkRunning && !installer_updated? && self_update_enabled?
    end

    # Return a message to be shown when the updates repo could not be probed
    #
    # @param url [URI,String] Repository URI
    # @return [String] Message including the repository URL
    #
    # @see #self_update_url
    def could_not_probe_repo_msg(url)
      # Note: the proxy cannot be configured in the YaST installer yet,
      # it needs to be set via the "proxy" boot option.
      # TRANSLATORS: %s is an URL
      format(_("Downloading the optional installer updates from \n%s\nfailed.\n" \
        "\n" \
        "You can continue the installation without applying the updates.\n" \
        "However, some potentially important bug fixes might be missing.\n" \
        "\n" \
        "If you need a proxy server to access the update repository\n" \
        "then use the \"proxy\" boot parameter.\n"), url.to_s)
    end

    # Require registration libraries
    #
    # @raise LoadError
    def require_registration_libraries
      return @require_registration_libraries unless @require_registration_libraries.nil?
      require "registration/url_helpers"
      require "registration/registration"
      require "registration/ui/regservice_selection_dialog"
      require "registration/exceptions"
      @require_registration_libraries = true
    rescue LoadError
      log.info "yast2-registration is not available"
      @require_registration_libraries = false
    end

    # Store URL of registration server to be used by inst_scc client
    #
    def store_registration_url
      return unless require_registration_libraries
      url = Registration::Storage::InstallationOptions.instance.custom_url
      return if url.nil?
      data = { "custom_url" => url.to_s }
      File.write(REGISTRATION_DATA_PATH, data.to_yaml)
    end

    # Load URL of registration server to be used by inst_scc client
    #
    # @return [Boolean] true if data was loaded; false otherwise.
    def load_registration_url
      return false unless File.exist?(REGISTRATION_DATA_PATH) && require_registration_libraries
      data = YAML.load(File.read(REGISTRATION_DATA_PATH))
      Registration::Storage::InstallationOptions.instance.custom_url = data["custom_url"]
      ::FileUtils.rm_rf(REGISTRATION_DATA_PATH)
      true
    end

    # Initialize the package management so we can download the updates from
    # the update repository.
    def initialize_packager
      return if @packager_initialized
      log.info "Initializing the package management..."

      # Add the initial installation repository.
      # Unfortunately the Packages.InitializeCatalogs call cannot be used here
      # as is does too much (adds y2update.tgz, selects the product, selects
      # the default patterns, looks for the addon product files...).

      # initialize package callbacks to show a progress while downloading the files
      PackageCallbacks.InitPackageCallbacks

      # set the language for the package manager (mainly error messages)
      Pkg.SetTextLocale(Language.language)

      # set the target to inst-sys otherwise libzypp complains in the GPG check
      Pkg.TargetInitialize("/")

      # load the GPG keys (*.gpg files) from inst-sys
      Packages.ImportGPGKeys

      @packager_initialized = true
    end

    # delete all added installation repositories
    # to make sure there is no leftover which could affect the installation later
    def finish_packager
      return unless @packager_initialized
      # false = all repositories, even the disabled ones
      Pkg.SourceGetCurrent(false).each { |r| Pkg.SourceDelete(r) }
      Pkg.SourceSaveAll
      Pkg.SourceFinishAll
      Pkg.TargetFinish
    end

    # Show global self update progress
    def initialize_progress
      stages = [
        # TRANSLATORS: progress label
        _("Add Update Repository"),
        _("Download the Packages"),
        _("Copy the Addon Packages"),
        _("Apply the Packages"),
        _("Restart")
      ]

      # open a new wizard dialog with title on the top
      # (the default dialog with title on the left looks ugly with the
      # Progress dialog)
      Yast::Wizard.CreateDialog
      @wizard_open = true

      Yast::Progress.New(
        # TRANSLATORS: dialog title
        _("Updating the Installer..."),
        # TRANSLATORS: progress title
        _("Updating the Installer..."),
        # max is 100%
        100,
        # stages
        stages,
        # steps
        [],
        # help text
        ""
      )

      # mark the first stage active
      Yast::Progress.NextStage
    end

    # Finish the self update progress
    def finish_progress
      return unless @wizard_open

      Yast::Progress.Finish
      Yast::Wizard.CloseDialog
    end

  private

    #
    # TODO: Most of the code responsable of process the profile has been
    # obtained from which inst_autoinit client in yast2-autoinstallation.
    # We should try to move it to a independent class or to Yast::Profile.
    #

    # @return [Boolean] true if the scheme is not forbidden
    def profile_valid_scheme?
      !PROFILE_FORBIDDEN_SCHEMES.include? AutoinstConfig.scheme
    end

    # Obtains the current profile
    #
    # @return [Hash, nil] current profile if not empty; nil otherwise
    #
    # @see Yast::Profile.current
    def current_profile
      return nil if Profile.current == {}

      Profile.current
    end

    # Fetch the profile from the given URI
    #
    # @return [Hash, nil] current profile if fetched or exists; nil otherwise
    #
    # @see Yast::Profile.current
    def fetch_profile
      return current_profile if current_profile

      if !profile_valid_scheme?
        Report.Warning("The scheme used (#{AutoinstConfig.scheme}), " \
                       "is not supported in self update.")
        return nil
      end

      process_location

      if !current_profile
        secure_uri = Yast::URL.HidePassword(AutoinstConfig.OriginalURI)
        log.info("Unable to load the profile from: #{secure_uri}")

        return nil
      end

      if !Profile.ReadXML(AutoinstConfig.xml_tmpfile)
        Report.Warning(_("Error while parsing the control file.\n\n"))
        return nil
      end

      current_profile
    end

    # Imports Report settings from the current profile
    def profile_prepare_reports
      report = Profile.current["report"]
      Report.Import(report)
    end

    # Imports general settings from the profile and set signature callbacks
    def profile_prepare_signatures
      AutoinstGeneral.Import(Profile.current.fetch("general", {}))
      AutoinstGeneral.SetSignatureHandling
    end

    # Fetch profile and prepare reports and signature callbas in case of
    # obtained a valid one.
    def process_profile
      log.info("Fetching the profile")
      return false if !fetch_profile

      profile_prepare_reports
      profile_prepare_signatures
    end

    # It retrieves the profile and the user rules from the given location
    #
    # @see ProfileLocation.Process
    def process_location
      log.info("Processing profile location...")
      ProfileLocation.Process
    end

    #
    # Copy the addon packages from the self-update repositories to the inst-sys
    #
    def copy_addon_packages
      log.info("Copying optional addon packages from the self update repositories...")
      updates_manager.repositories.each do |u|
        ::Installation::SelfupdateAddonRepo.copy_packages(u.repo_id)
      end
    end
  end
end

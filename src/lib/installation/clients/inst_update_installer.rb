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
require "uri"
require "yaml"

module Yast
  class InstUpdateInstaller
    include Yast::Logger
    include Yast::I18n

    UPDATED_FLAG_FILENAME = "installer_updated".freeze
    REMOTE_SCHEMES = ["http", "https", "ftp", "tftp", "sftp", "nfs", "nfs4", "cifs", "smb"].freeze
    PROFILE_VALID_SCHEMES   = ["http", "https", "ftp", "tftp", "sftp"].freeze
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


    def main
      textdomain "installation"

      return :back if GetInstArgs.going_back

      if Installation.restarting?
        load_registration_url
        Installation.finish_restarting!
      end

      # shortcut - already updated
      return :next if installer_updated?

      initialize_progress

      if Mode.auto
        log.info("Fetching profile")

        return :next unless fetch_profile
        Yast::Progress.NextStage
      end

      # initialize packager, we need to load the base product name
      # to properly obtain the update URL from the registration server
      return :abort unless initialize_packager

      # self update disabled or not possible
      return :next unless try_to_update?

      log.info("Trying installer update")
      installer_updated = update_installer

      finish_packager

      if installer_updated
        # Indicates that the installer was updated.
        ::FileUtils.touch(update_flag_file)
        Yast::Progress.NextStage
        Installation.restart!
      else
        :next
      end
    ensure
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
    #   configuration if URL has a REMOTE_SCHEME.
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      updated = self_update_urls.map { |u| add_repository(u) }.any?

      if updated
        log.info("Applying installer updates")
        Yast::Progress.NextStage
        updates_manager.apply_all
      end
      updated
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
      if Linuxrc.InstallInf("SelfUpdate") == "0" # disabled via Linuxrc
        log.info("self-update was disabled through Linuxrc")
        false
      else
        !self_update_urls.empty?
      end
    end

    # Return the self-update URLs
    #
    # @return [Array<URI>] self-update URLs
    #
    # @see #default_self_update_url
    # @see #custom_self_update_url
    def self_update_urls
      return @self_update_urls if @self_update_urls
      @self_update_urls = Array(custom_self_update_url)
      @self_update_urls = default_self_update_urls if @self_update_urls.empty?
      log.info("self-update URLs are #{@self_update_urls}")
      @self_update_urls
    end

    # Return the default self-update URLs
    #
    # A default URL can be specified via SCC/SMT servers or in the control.xml file.
    #
    # @return [Array<URI>] self-update URLs
    def default_self_update_urls
      return @default_self_update_urls if @default_self_update_urls
      @default_self_update_urls = self_update_url_from_connect
      return @default_self_update_urls unless @default_self_update_urls.empty?
      @default_self_update_urls = Array(self_update_url_from_control)
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

    # Return the self-update URLs from SCC/SMT server
    #
    # Return an empty array if yast2-registration or SUSEConnect are not
    # available (for instance in openSUSE). More than 1 URLs can be found.
    #
    # As a side effect, it stores the URL of the registration server used
    # in the installation options.
    #
    # @return [Array<URI>] self-update URLs.
    def self_update_url_from_connect
      return [] unless require_registration_libraries
      url = registration_url
      return [] if url == :cancel

      log.info("Using registration URL: #{url}")
      import_registration_ayconfig if Mode.auto
      registration = Registration::Registration.new(url == :scc ? nil : url.to_s)
      # Set custom_url into installation options
      Registration::Storage::InstallationOptions.instance.custom_url = registration.url
      store_registration_url(url) if url != :scc
      registration.get_updates_list.map { |u| URI(u.url) }
    end

    # Return the URL of the preferred registration server
    #
    # Determined in the following order:
    #
    # * "regurl" boot parameter
    # * From AutoYaST profile
    # * SLP look up
    #   * In AutoYaST mode the SLP needs to be explicitly enabled in the profile,
    #     if the scan finds *exactly* one SLP service then it is used. If more
    #     than one service is found then an interactive popup is displayed.
    #     (This breaks the AY unattended concept but basically more services
    #     is treated as an error, AytoYaST cannot know which one to use.)
    #   * In non-AutoYaST mode it will ask the user to choose the found SLP
    #     servise or the SCC default.
    #  * Fallbacks to SCC if no SLP service is found.
    #
    # @return [URI,:scc,:cancel] Registration URL; :scc if SCC server was selected;
    #                            :cancel if dialog was dismissed.
    #
    # @see #registration_service_from_user
    def registration_url
      url = ::Registration::UrlHelpers.boot_reg_url || registration_url_from_profile
      return URI(url) if url

      # do the SLP scan in AutoYast mode only when allowed in the profile
      return :scc if Mode.auto && registration_profile["slp_discovery"] != true

      services = ::Registration::UrlHelpers.slp_discovery
      log.info "SLP discovery result: #{services.inspect}"
      return :scc if services.empty?

      service =
        if Mode.auto && services.size == 1
          services.first
        else
          registration_service_from_user(services)
        end

      log.info "Selected SLP service: #{service.inspect}"

      return service unless service.respond_to?(:slp_url)
      URI(::Registration::UrlHelpers.service_url(service.slp_url))
    end

    # Return the registration server URL from the AutoYaST profile
    #
    # @return [URI,nil] the self-update URL, nil if not running in AutoYaST mode
    #   or when the URL is not defined in the profile
    def registration_url_from_profile
      return nil unless Mode.auto

      # TODO: download the AutoYaST profile first
      # see ../../lib/transfer/file_from_url.rb#L89

      get_url_from(registration_profile["reg_server"])
    end

    # return the registration settings from the loaded AutoYaST profile
    # @return [Hash] the current settings, returns empty Hash if the
    #   registration section is missing in the profile
    def registration_profile
      profile = Yast::Profile.current
      profile.fetch("suse_register", {})
    end

    # Ask the user to chose a registration server
    #
    # @param services [Array<SlpServiceClass::Service>] Array of registration servers
    # @return [SlpServiceClass::Service,Symbol] Registration service to use; :scc if SCC is selected;
    #                                           :cancel if the dialog was dismissed.
    def registration_service_from_user(services)
      ::Registration::UI::RegserviceSelectionDialog.run(
        services:    services,
        description: _("Select a detected registration server from the list\n" \
          "to search for installer updates.")
      )
    end

    # Return the self-update URL according to product's control file
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in control file.
    def self_update_url_from_control
      get_url_from(ProductFeatures.GetStringFeature("globals", "self_update_url"))
    end

    # Return the self-update URL according to Linuxrc
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in Linuxrc.
    def self_update_url_from_linuxrc
      get_url_from(Linuxrc.InstallInf("SelfUpdate"))
    end

    # Return the self-update URL from the AutoYaST profile
    #
    # @return [URI,nil] the self-update URL, nil if not running in AutoYaST mode
    #   or when the URL is not defined in the profile
    def self_update_url_from_profile
      return nil unless Mode.auto

      profile = Yast::Profile.current
      profile_url = profile.fetch("general", {})["self_update_url"]

      get_url_from(profile_url)
    end

    # Converts the string into an URI if it's valid
    #
    # It substitutes $arch pattern with the architecture of the current system.
    #
    # @return [URI,nil] The string converted into a URL; nil if it's
    #                   not a valid URL.
    #
    # @see URI.regexp
    def get_url_from(url)
      return nil unless url.is_a?(::String)
      real_url = url.gsub(/\$arch\b/, Pkg.GetArchitecture)
      URI.regexp.match(real_url) ? URI(real_url) : nil
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
    # @param url [URI] Repository URL
    # @return [Boolean] true if the repository was added; false otherwise.
    def add_repository(url)
      log.info("Adding update from #{url}")
      updates_manager.add_repository(url)

    rescue ::Installation::UpdatesManager::NotValidRepo
      if !default_url?(url)
        # TRANSLATORS: %s is an URL
        Report.Error(format(_("A valid update could not be found at\n%s.\n\n"), url))
      end
      false

    rescue ::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo
      # TRANSLATORS: %s is an URL
      Report.Error(format(_("Could not fetch update from\n%s.\n\n"), url))
      false

    rescue ::Installation::UpdatesManager::CouldNotProbeRepo
      msg = could_not_probe_repo_msg(url)
      if Mode.auto
        Report.Warning(msg)
      elsif remote_url?(url) && configure_network?(msg)
        retry
      end
      false
    end

    # Determine whether the URL is remote
    #
    # @param url [URI] URL to check
    # @return [Boolean] true if it's considered remote; false otherwise.
    def remote_url?(url)
      REMOTE_SCHEMES.include?(url.scheme)
    end

    # Launch the network configuration client on users' demand
    #
    # Ask the user about checking network configuration. If she/he accepts,
    # the `inst_lan` client will be launched.
    #
    # @param url [URI] URL to show in the message
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
    # * Installer is not updated yet.
    # * Self-update feature is enabled.
    # * Network is up.
    #
    # @return [Boolean] true if the update should be performed; false otherwise.
    #
    # @see #installer_updated?
    # @see #self_update_enabled?
    # @see NetworkService.isNetworkRunning
    def try_to_update?
      !installer_updated? && self_update_enabled? && NetworkService.isNetworkRunning
    end

    # Determines whether the given URL is equal to the default one
    #
    # @return [Boolean] true if it's the default URL; false otherwise.
    def default_url?(uri)
      default_self_update_urls.include?(uri)
    end

    # Return a message to be shown when the updates repo could not be probed
    #
    # @param [URI,String] Repository URI
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
      require "registration/url_helpers"
      require "registration/registration"
      require "registration/ui/regservice_selection_dialog"
      true
    rescue LoadError
      log.info "yast2-registration is not available"
      false
    end

    # Store URL of registration server to be used by inst_scc client
    #
    # @params [URI] Registration server URL.
    def store_registration_url(url)
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

    # Load registration configuration from AutoYaST profile
    #
    # This data will be used by Registration::ConnectHelpers.catch_registration_errors.
    #
    # @see Yast::Profile.current
    def import_registration_ayconfig
      ::Registration::Storage::Config.instance.import(
        Yast::Profile.current.fetch("suse_register", {})
      )
    end

    # Initialize the package management so we can download the updates from
    # the update repository.
    def initialize_packager
      log.info "Initializing the package management..."

      # Add the initial installation repository.
      # Unfortunately the Packages.InitializeCatalogs call cannot be used here
      # as is does too much (adds y2update.tgz, selects the product, selects
      # the default patterns, looks for the addon product files...).

      # initialize package callbacks to show a progress while downloading the files
      PackageCallbacks.InitPackageCallbacks

      # set the language for the package manager (mainly error messages)
      Pkg.SetTextLocale(Language.language)

      # load the GPG keys (*.gpg files) from inst-sys
      Packages.ImportGPGKeys

      base_url = InstURL.installInf2Url("")
      initial_repository = Pkg.SourceCreateBase(base_url, "")

      until initial_repository
        log.error "Adding the installation repository failed"
        # ask user to retry
        base_url = Packages.UpdateSourceURL(base_url)

        # aborted by user
        return false if base_url == ""

        initial_repository = Pkg.SourceCreateBase(base_url, "")
      end

      true
    end

    # delete all added installation repositories
    # to make sure there is no leftover which could affect the installation later
    def finish_packager
      # false = all repositories, even the disabled ones
      Pkg.SourceGetCurrent(false).each { |r| Pkg.SourceDelete(r) }
      Pkg.SourceSaveAll
    end

    # Show global self update progress
    def initialize_progress
      stages = [
        # TRANSLATORS: progress label
        _("Add Update Repository"),
        _("Download the Packages"),
        _("Apply the Packages"),
        _("Restart")
      ]

      stages.unshift(_("Fetching AutoYast Profile")) if Mode.auto && profile_given?

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

    def profile_given?
      url = SCR.Read(Yast::Path.new(".etc.install_inf.AutoYaST"))

      url.to_s.empty? ? false : true
    end

    def profile_valid_scheme?
      PROFILE_VALID_SCHEMES.include? Yast::AutoinstConfig.scheme
    end

    def current_profile
      return nil if Yast::Profile.current == {}

      Yast::Profile.current
    end

    def fetch_profile
      return current_profile if current_profile

      if !profile_valid_scheme?
        Report.Error(format(_("Not supported scheme %s.\n\n"), Yast::AutoinstConfig.scheme))
        return nil
      end

      Yast::ProfileLocation.Process

      while !current_profile
        return nil if ask_profile_uri.nil?

        Yast::ProfileLocation.Process
      end

      if !Yast::Profile.ReadXML(Yast::AutoinstConfig.xml_tmpfile)
        Report.Error(_("Error while parsing the control file.\n\n"))
        return nil
      end

      # TODO:
      #  * Should be reported non supported sections at this point?
      #  * Check if Yast::AutoinstGeneral.SetSignatureHandling is needed

      current_profile
    end

    def ask_profile_uri
      newURI = ProfileLocation.ProfileSourceDialog(AutoinstConfig.OriginalURI)
      return nil if newURI.empty?

      # Updating new URI in /etc/install.inf (bnc#963487)
      # SCR.Write does not work in inst-sys here.
      WFM.Execute(
        Yast::Path.new(".local.bash"),
        "sed -i \'/AutoYaST:/c\AutoYaST: #{newURI}\' /etc/install.inf"
      )

      AutoinstConfig.ParseCmdLine(newURI)
      AutoinstConfig.SetProtocolMessage

      newURI
    end
  end
end

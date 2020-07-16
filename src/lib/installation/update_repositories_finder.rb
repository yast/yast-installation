# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
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
require "installation/update_repository"
require "uri"

Yast.import "Pkg"
Yast.import "Packages"
Yast.import "PackageCallbacks"
Yast.import "InstURL"
Yast.import "Linuxrc"
Yast.import "Mode"
Yast.import "Profile"
Yast.import "ProductFeatures"
Yast.import "InstFunctions"
Yast.import "OSRelease"

module Installation
  # Invalid registration URL error
  class RegistrationURLError < URI::InvalidURIError; end

  # This class find repositories to be used by the self-update feature.
  class UpdateRepositoriesFinder
    include Yast::Logger
    include Yast::I18n

    # Constructor
    def initialize
      textdomain "installation"
    end

    # Return the update source
    def updates
      return @updates if @updates

      @updates = Array(custom_update) # Custom URL
      return @updates unless @updates.empty?

      @updates = updates_from_connect
      return @updates unless @updates.empty?

      @updates = Array(update_from_control)
    end

  private

    # Return the self-update repository if defined by the user
    #
    # It tries to find an URL in Linuxrc boot parameters and
    # AutoYaST profile.
    #
    # @return [UpdateRepository,nil] self-update repository or nil if not defined
    #
    # @see update_url_from_linuxrc
    # @see update_url_from_profile
    def custom_update
      url = update_url_from_linuxrc || update_url_from_profile
      url && UpdateRepository.new(url, :user)
    end

    # Return the self-update repository defined in the control file
    #
    # @return [UpdateRepository,nil] self-update repository or nil if not defined
    def update_from_control
      url = update_url_from_control
      url && UpdateRepository.new(url, :default)
    end

    # Return the self-update repository defined in the registration server
    #
    # @return [Array<UpdateRepository>] self-update repositories
    def updates_from_connect
      return [] unless defined?(::Registration::UrlHelpers)
      # load the base product from the installation medium,
      # the registration server needs it for evaluating the self update URL
      add_installation_repo
      urls = update_urls_from_connect
      urls ? urls.map { |u| UpdateRepository.new(u, :default) } : []
    end

    # Return the self-update URL according to Linuxrc
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in Linuxrc.
    def update_url_from_linuxrc
      get_url_from(Yast::Linuxrc.InstallInf("SelfUpdate"))
    end

    # Return the self-update URL from the AutoYaST profile
    #
    # @return [URI,nil] the self-update URL, nil if not running in AutoYaST mode
    #   or when the URL is not defined in the profile
    def update_url_from_profile
      return nil unless Yast::Mode.auto

      Yast.import "AutoinstGeneral"
      profile_url = Yast::AutoinstGeneral.self_update_url

      get_url_from(profile_url)
    end

    # Return the self-update URL according to product's control file
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in control file.
    def update_url_from_control
      get_url_from(Yast::ProductFeatures.GetStringFeature("globals", "self_update_url"))
    end

    # Return the self-update URLs from SCC/SMT server
    #
    # Return an empty array if yast2-registration or SUSEConnect are not
    # available (for instance in openSUSE). More than 1 URLs can be found.
    #
    # As a side effect, it stores the URL of the registration server used
    # in the installation options.
    #
    # @return [Array<URI>,false] self-update URLs or false in case of error
    def update_urls_from_connect
      begin
        url = registration_url
      rescue URI::InvalidURIError
        raise RegistrationURLError
      end

      return [] if url == :cancel

      custom_regserver = url != :scc
      log.info("Using registration URL: #{url}")
      import_registration_ayconfig if Yast::Mode.auto
      registration = Registration::Registration.new(custom_regserver ? url.to_s : nil)
      # Set custom_url into installation options
      Registration::Storage::InstallationOptions.instance.custom_url = registration.url

      show_errors = custom_regserver || Yast::InstFunctions.self_update_explicitly_enabled?
      handle_registration_errors(show_errors) do
        registration.get_updates_list.map { |u| URI(u.url) }
      end
    end

    # Converts the string into an URI if it's valid
    #
    # Substituting $arch pattern with the architecture of the current system.
    # Substituting $os_release_version pattern with the release of the current system.
    #
    # @return [URI,nil] The string converted into a URL; nil if it's
    #                   not a valid URL.
    #
    # @see URI.regexp
    def get_url_from(url)
      return nil unless url.is_a?(::String)
      real_url = url.gsub(/\$arch\b/, Yast::Pkg.GetArchitecture)
      real_url = real_url.gsub(/\$os_release_version\b/,
        Yast::OSRelease.ReleaseVersionHumanReadable)
      URI.regexp.match(real_url) ? URI(real_url) : nil
    end

    # Loads the base product from the installation medium
    def add_installation_repo
      base_url = Yast::InstURL.installInf2Url("")
      initial_repository = Yast::Pkg.SourceCreateBase(base_url, "")

      until initial_repository
        log.error "Adding the installation repository failed"
        # ask user to retry
        base_url = Packages.UpdateSourceURL(base_url)

        # aborted by user
        return false if base_url == ""

        initial_repository = Yast::Pkg.SourceCreateBase(base_url, "")
      end
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
      return :scc if Yast::Mode.auto && registration_profile["slp_discovery"] != true

      services = ::Registration::UrlHelpers.slp_discovery
      log.info "SLP discovery result: #{services.inspect}"
      return :scc if services.empty?

      service =
        if Yast::Mode.auto && services.size == 1
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
      return nil unless Yast::Mode.auto

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

    # Runs a block of code handling errors
    #
    # If errors should be shown, the helper {catch_registration_errors}
    # from Registration::ConnectHelpers will be used.
    #
    # Otherwise, errors will be logged and the method will return +false+.
    #
    # @param [Boolean] show_errors True if errors should be shown to the user. False otherwise.
    # @return [false, Object] The value returned by the block itself. False
    #                         if the block failed.
    #
    # @see Registration::ConnectHelpers.catch_registration_errors
    def handle_registration_errors(show_errors)
      if show_errors
        require "registration/connect_helpers"
        ret = nil
        success = ::Registration::ConnectHelpers.catch_registration_errors { ret = yield }
        success && ret
      else
        begin
          yield
        rescue StandardError => e
          log.warn("Could not determine update repositories through the registration server: " \
            "#{e.class}: #{e}, #{e.backtrace}")
          false
        end
      end
    end
  end
end

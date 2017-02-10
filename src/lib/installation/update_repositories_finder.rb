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
Yast.import "Report"

module Installation
  # This class find repositories to be used by the self-update feature.
  class UpdateRepositoriesFinder
    include Yast::Logger
    include Yast::I18n

    # Return the update source
    def updates
      return @updates if @updates

      @updates = Array(custom_update)
      return @updates unless @updates.empty?
      default_updates
    end

    private

    # Return the self-update repository if defined by the user
    #
    # It tries to find an URL in Linuxrc boot parameters and
    # AutoYaST profile.
    #
    # @return [UpdateRepository] self-update repository
    #
    # @see update_url_from_linuxrc
    # @see update_url_from_profile
    def custom_update
      url = update_url_from_linuxrc || update_url_from_profile
      url ? UpdateRepository.new(url, :user) : nil
    end

    def default_updates
      urls = default_urls
      urls.map { |u| UpdateRepository.new(u, :default) }
    end

    # Return the default self-update URLs
    #
    # A default URL can be specified via SCC/SMT servers or in the control.xml file.
    #
    # @return [Array<URI>] self-update URLs
    def default_urls
      # load the base product from the installation medium,
      # the registration server needs it for evaluating the self update URL
      # TODO: not needed in opensuse (should we move it to update_urls_from_connect)
      add_installation_repo
      urls = update_urls_from_connect
      return urls unless urls.empty?
      [update_url_from_control].compact
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

      profile = Yast::Profile.current
      profile_url = profile.fetch("general", {})["self_update_url"]

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
    # @return [Array<URI>] self-update URLs.
    def update_urls_from_connect
      return [] unless defined?(::Registration::UrlHelpers)
      url = registration_url
      return [] if url == :cancel

      log.info("Using registration URL: #{url}")
      import_registration_ayconfig if Yast::Mode.auto
      registration = Registration::Registration.new(url == :scc ? nil : url.to_s)
      # Set custom_url into installation options
      Registration::Storage::InstallationOptions.instance.custom_url = registration.url
      ret = registration.get_updates_list.map { |u| URI(u.url) }

      # avoid unless using a custom registration server
      display_fallback_warning if ret.empty?

      ret
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
      real_url = url.gsub(/\$arch\b/, Yast::Pkg.GetArchitecture)
      URI.regexp.match(real_url) ? URI(real_url) : nil
    end

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

    # Display a warning message about using the default update URL from
    # control.xml when the registration server does not return any URL or fails.
    # In AutoYaST mode the dialog is closed after a timeout.
    def display_fallback_warning
      # TRANSLATORS: error message
      msg = _("<p>Cannot obtain the installer update repository URL\n" \
        "from the registration server.</p>")

      if update_url_from_control
        # TRANSLATORS: part of an error message, %s is the default repository
        # URL from control.xml
        msg += _("<p>The default URL %s will be used.<p>") % update_url_from_control
      end

      # display the message in a RichText widget to wrap long lines
      Yast::Report.LongWarning(msg)
    end
  end
end

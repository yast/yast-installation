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

module Yast
  class InstUpdateInstaller
    include Yast::Logger
    include Yast::I18n

    UPDATED_FLAG_FILENAME = "installer_updated".freeze
    REMOTE_SCHEMES = ["http", "https", "ftp", "tftp", "sftp", "nfs", "nfs4", "cifs", "smb"].freeze

    Yast.import "Pkg"
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

    def main
      textdomain "installation"

      return :back if GetInstArgs.going_back

      Installation.finish_restarting! if Installation.restarting?

      return :next unless try_to_update?

      log.info("Trying installer update")

      if update_installer
        ::FileUtils.touch(update_flag_file) # Indicates that the installer was updated.
        Installation.restart!
      else
        :next
      end
    end

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
        !self_update_url.nil?
      end
    end

    # Return the self-update URL
    #
    # @return [URI] self-update URL
    #
    # @see #self_update_url_from_linuxrc
    # @see #self_update_url_from_control
    # @see #self_update_url_from_profile
    def self_update_url
      url = self_update_url_from_linuxrc || self_update_url_from_profile ||
        self_update_url_from_control
      log.info("self-update URL is #{url}")
      url
    end

    # Return the self-update URL according to Linuxrc
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in Linuxrc.
    def self_update_url_from_linuxrc
      get_url_from(Linuxrc.InstallInf("SelfUpdate"))
    end

    # Return the self-update URL according to product's control file
    #
    def self_update_url_from_control
      get_url_from(ProductFeatures.GetStringFeature("globals", "self_update_url"))
    end

    # Return the self-update URL from the AutoYaST profile
    # @return [URI,nil] the self-update URL, nil if not running in AutoYaST mode
    #   or when the URL is not defined in the profile
    def self_update_url_from_profile
      return nil unless Mode.auto

      Yast.import "Profile"
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
      log.info("Adding update from #{self_update_url}")
      updates_manager.add_repository(self_update_url)
      updated = updates_manager.repositories?
      if updated
        log.info("Applying installer updates")
        updates_manager.apply_all
      end
      updated

    rescue ::Installation::UpdatesManager::NotValidRepo
      if !using_default_url?
        # TRANSLATORS: %s is an URL
        Report.Error(format(_("A valid update could not be found at\n%s.\n\n"), self_update_url))
      end
      false

    rescue ::Installation::UpdatesManager::CouldNotFetchUpdateFromRepo
      # TRANSLATORS: %s is an URL
      Report.Error(format(_("Could not fetch update from\n%s.\n\n"), self_update_url))
      false

    rescue ::Installation::UpdatesManager::CouldNotProbeRepo
      if Mode.auto
        Report.Error(could_not_probe_repo_msg)
      else
        retry if remote_self_update_url? && configure_network?
      end
      false
    end

    # Determine whether the URL is remote
    #
    # @return [Boolean] true if it's considered remote; false otherwise.
    def remote_self_update_url?
      REMOTE_SCHEMES.include?(self_update_url.scheme)
    end

    # Launch the network configuration client on users' demand
    #
    # Ask the user about checking network configuration. If she/he accepts,
    # the `inst_lan` client will be launched.
    #
    # @return [Boolean] true if the network configuration client was launched;
    #                   false if the network is not configured.
    def configure_network?
      msg = could_not_probe_repo_msg + "\n" \
        "Would you like to check your network configuration\n" \
        "and try installing the updates again?"

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
    def using_default_url?
      self_update_url_from_control == self_update_url
    end

    # Return a message to be shown when the updates repo could not be probed
    #
    # @return [String] Message including the repository URL
    #
    # @see #self_update_url
    def could_not_probe_repo_msg
      # Note: the proxy cannot be configured in the YaST installer yet,
      # it needs to be set via the "proxy" boot option.
      # TRANSLATORS: %s is an URL
      format(_("Downloading the optional installer updates from \n%s\nfailed.\n" \
        "\n" \
        "You can continue the installation without applying the updates.\n" \
        "However, some potentially important bug fixes might be missing.\n" \
        "\n" \
        "If you need a proxy server to access the update repository\n" \
        "then use the \"proxy\" boot parameter.\n"), self_update_url)
    end

  end
end

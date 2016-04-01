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

    UPDATED_FLAG_FILENAME = "installer_updated"

    Yast.import "Arch"
    Yast.import "Directory"
    Yast.import "Installation"
    Yast.import "ProductFeatures"
    Yast.import "Label"
    Yast.import "Linuxrc"
    Yast.import "Popup"
    Yast.import "Report"
    Yast.import "NetworkService"

    def main
      textdomain "installation"

      return :next unless try_to_update?

      log.info("Trying installer update")

      if update_installer
        ::FileUtils.touch(update_flag_file) # Indicates that the installer was updated.
        ::FileUtils.touch(Installation.restart_file)
        :restart_yast # restart YaST to apply modifications.
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
    def self_update_url
      url = self_update_url_from_linuxrc || self_update_url_from_control
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
      real_url = url.gsub(/\$arch\b/, Arch.architecture)
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
    # It also shows feedback to the user.
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      fetch_update ? apply_update : false
    end

    # Fetch updates from self_update_url
    #
    # @return [Boolean] true if update was fetched successfully; false otherwise.
    def fetch_update
      ret = updates_manager.add_repository(self_update_url)
      log.info("Adding update from #{self_update_url} (ret = #{ret})")
      if ret == :not_found && !using_default_url? # not found (quite expected)
        Report.Error(_("A valid update could not be found at #{self_update_url}"))
      elsif ret == :error # found but an error occurred
        Report.Error(_("Could not read update information from #{self_update_url}"))
      end
      ret == :ok
    end

    # Apply the updates and shows feedback information
    #
    # @return [Boolean] true if the update was applied; false otherwise
    def apply_update
      log.info("Applying installer updates")
      updates_manager.apply_all
      true
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

    # Determines whether the given URL is equals to the default one
    def using_default_url?
      self_update_url_from_control == self_update_url
    end
  end
end

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
  class InstUpdateInstaller < Client
    include Yast::Logger

    UPDATED_FLAG_FILENAME = "installer_updated"
    URL_SUPPORTED_SCHEMES = ["http", "https", "ftp"]

    Yast.import "Directory"
    Yast.import "Installation"
    Yast.import "ProductFeatures"
    Yast.import "Linuxrc"
    Yast.import "Popup"

    # TODO
    #
    # * Handle unsigned files
    def main

      return :next if installer_updated? || !self_update_enabled?

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
      self_update_url_from_linuxrc || self_update_url_from_control
    end

    # Return the self-update URL according to Linuxrc
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in Linuxrc.
    def self_update_url_from_linuxrc
      url = URI(Linuxrc.InstallInf("SelfUpdate") || "")
      valid_url?(url) ? url : nil
    end

    # Return the self-update URL according to product's control file
    #
    # @return [URI,nil] self-update URL. nil if no URL was set in control file.
    def self_update_url_from_control
      url = URI(ProductFeatures.GetStringFeature("globals", "self_update_url"))
      valid_url?(url) ? url : nil
    end

    # Determines whether the URL is valid or no
    #
    # @return [Boolean] True if it's valid; false otherwise.
    #
    # @see URL_SUPPORTED_SCHEMES
    def valid_url?(url)
      URL_SUPPORTED_SCHEMES.include?(url.scheme) ? url : false
    end

    # Check if installer was updated
    #
    # It checks if a file UPDATED_FLAG_FILENAME exists in Directory.vardir
    #
    # @return [Boolean] true if it exists; false otherwise.
    def installer_updated?
      File.exist?(update_flag_file)
    end

    # Returns the name of the "update flag file"
    #
    # @return [String] Path to the "update flag file"
    #
    # @see #update_installer
    def update_flag_file
      File.join(Directory.vardir, UPDATED_FLAG_FILENAME)
    end

    # Determines whether the update is running in insecure mode
    #
    # @return [Boolean] true if running in insecure mode; false otherwise.
    def insecure_mode?
      Linuxrc.InstallInf("Insecure") == "1" # Insecure mode is enabled
    end

    # Ask the user if she/he wants to apply the update although it's not properly signed
    #
    # @return [Boolean] true if user answered 'Yes'; false otherwise.
    def ask_insecure?
      Popup.AnyQuestion(
        Label::WarningMsg(),
        _("Installer update is not signed or signature is invalid. Do you want to apply this update?"),
        _("Yes, apply and continue"),
        _("No, skip and continue"),
        :focus_yes
      )
    end

    # Tries to update the installer
    #
    # It also shows feedback to the user.
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      if fetch_update
        apply_update
      else
        false
      end
    end

    # Fetch updates from self_update_url
    #
    # @return [Boolean] true if update was fetched successfully; false otherwise.
    def fetch_update
      ret = nil
      Popup.Feedback(_("YaST2 update"), _("Searching for installer updates")) do
        ret = updates_manager.add_update(self_update_url)
      end
      Popup.Error(_("Update could not be found")) unless ret || using_default_url?
      ret
    end

    # Apply the updates and shows feedback information
    #
    # @return [Boolean] true if the update was applied; false otherwise
    def apply_update
      if updates_manager.all_signed? || insecure_mode? || ask_insecure?
        Popup.Feedback(_("YaST2 update"), _("Applying installer updates")) do
          updates_manager.apply_all
        end
      else
        false
      end
    end

    # Determines whether the given URL is equals to the default one
    def using_default_url?
      self_update_url_from_control == self_update_url
    end
  end
end

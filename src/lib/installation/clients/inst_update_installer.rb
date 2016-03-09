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

    # TODO
    #
    # * Handle unsigned files
    def main
      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "ProductFeatures"
      Yast.import "Linuxrc"

      return :next if installer_updated? || !self_update_enabled?

      if update_installer
        ::FileUtils.touch(update_flag_file) # Indicates that the installer was updated.
        ::FileUtils.touch(Installation.restart_file)
        :restart_yast # restart YaST to apply modifications.
      else
        :next
      end
    end

    # Tries to update the installer
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      manager = ::Installation::UpdatesManager.new
      if manager.add_update(self_update_url)
        manager.apply_all
      else
        false
      end
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
  end
end

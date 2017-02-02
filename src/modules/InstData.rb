# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	modules/InstData.ycp
# Package:	Installation
# Summary:	Installation Data (variables, maps, probed info)
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id: $
#
# This module provides an access to the installation data, e.g.,
# probed Linux partitions.
require "yast"

module Yast
  class InstDataClass < Module
    def main
      textdomain "installation"

      Yast.import "Directory"

      # --> system analysis

      @start_mode = nil

      # <-- system analysis

      # --> software selection

      @selected_desktop = nil

      @current_systasks_status = {}

      # <-- software selection
      #

      # --> other

      @product_license_accepted = false

      # keep steps disabled in first stage also disabled in second stage
      # see bnc #364066
      @wizardsteps_disabled_modules = Ops.add(
        Directory.vardir,
        "/installation_disabled_steps"
      )
      @wizardsteps_disabled_proposals = Ops.add(
        Directory.vardir,
        "/installation_disabled_proposals"
      )
      @wizardsteps_disabled_subproposals = Ops.add(
        Directory.vardir,
        "/installation_disabled_subproposals"
      )
      # temporary variables for disabling and enabling steps
      @localDisabledModules = []
      @localDisabledProposals = []

      # <-- other

      # --> copy files -- config
      # FATE #305019: configure the files to copy from a previous installation

      @copy_files_use_control_file = true

      @additional_copy_files = []

      # <-- copy files -- config

      # variables for OEM image installation

      # disk to use for OEM image
      @image_target_disk = nil

      # downloaded (also from media) release notes, product => text
      @release_notes = {}

      # list of release notes which were downloaded from internet (not from media)
      # only product names, not the actual RN text
      @downloaded_release_notes = []

      # list of release notes that YaST failed to download
      @failed_release_notes = []

      # remember that downloading release notes failed due to communication
      # issues with the server, avoid further attempts then
      @stop_relnotes_download = false

      # EOF
    end

    publish variable: :start_mode, type: "string"
    publish variable: :selected_desktop, type: "string"
    publish variable: :current_systasks_status, type: "map <string, boolean>"
    publish variable: :current_role_options, type: "map <string, string>"
    publish variable: :product_license_accepted, type: "boolean"
    publish variable: :wizardsteps_disabled_modules, type: "string"
    publish variable: :wizardsteps_disabled_proposals, type: "string"
    publish variable: :wizardsteps_disabled_subproposals, type: "string"
    publish variable: :localDisabledModules, type: "list <string>"
    publish variable: :localDisabledProposals, type: "list <string>"
    publish variable: :copy_files_use_control_file, type: "boolean"
    publish variable: :additional_copy_files, type: "list <map>"
    publish variable: :image_target_disk, type: "string"
    publish variable: :release_notes, type: "map<string,string>"
    publish variable: :downloaded_release_notes, type: "list<string>"
    publish variable: :stop_relnotes_download, type: "boolean"
    publish variable: :failed_release_notes, type: "list<string>"
  end

  InstData = InstDataClass.new
  InstData.main
end

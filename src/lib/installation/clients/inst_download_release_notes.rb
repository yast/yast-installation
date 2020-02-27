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

#
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# Purpose:	Downloads on-line release notes
#
# $Id$

require "y2packager/product"
require "y2packager/product_reader"

Yast.import "InstData"
Yast.import "Pkg"
Yast.import "Packages"
Yast.import "Stage"
Yast.import "UI"
Yast.import "GetInstArgs"
Yast.import "Wizard"
Yast.import "Mode"
Yast.import "Language"

module Yast
  # Client to download and manage release notes button
  #
  # This client ask for products' release notes and sets UI elements accordingly
  # ("Release Notes" button and dialog).
  class InstDownloadReleaseNotesClient < Client
    include Yast::Logger

    # Download release notes for all selected and installed products
    #
    # @return true when successful
    def download_release_notes
      format = UI.TextMode ? :txt : :rtf

      relnotes_map = products.each_with_object({}) do |product, all|
        relnotes = product.release_notes(Yast::Language.language, format)
        if relnotes.nil?
          log.info "No release notes were found for product #{product.short_name}"
          next
        end
        all[product.short_name] = relnotes.content
      end

      refresh_ui(relnotes_map)
      InstData.release_notes = relnotes_map
      !relnotes_map.empty?
    end

    # Set the UI content to show some progress.
    # FIXME: use a better title (reused existing texts because of text freeze)
    def init_ui
      Wizard.SetContents(_("Initializing"), Label(_("Initializing the installation...")),
        "", false, false)
    end

    def main
      textdomain "installation"

      return :auto unless Packages.init_called

      return :back if GetInstArgs.going_back

      # skip download during AutoYaST
      if Mode.auto
        log.info "Skipping release notes during AutoYaST-driven installation or upgrade"
        return :auto
      end

      init_ui

      download_release_notes
      :auto
    end

  private

    # List of products which should be used for downloading release notes
    #
    # @return [Array<Y2Packager::Product>] list of products
    def products
      # installed may mean old (before upgrade) in initial stage
      # product may not yet be selected although repo is already added
      #
      # Don't rely on Product.with_status() here, use force_repos (bsc#1158287)
      all_products = Y2Packager::ProductReader.new.all_products(force_repos: true)
      return all_products.select { |p| p.status?(:selected, :installed) } unless Stage.initial
      selected = all_products.select { |p| p.selected? }
      return selected unless selected.empty?
      all_products.select { |p| p.status?(:available) }
    end

    # Refresh release notes UI
    def refresh_ui(relnotes_map)
      UI.SetReleaseNotes(relnotes_map)
      if relnotes_map.empty?
        Wizard.HideReleaseNotesButton
      else
        Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
      end
    end
  end
end

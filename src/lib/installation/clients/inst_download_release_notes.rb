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
require "y2packager/exceptions"

Yast.import "InstData"
Yast.import "Pkg"
Yast.import "Packages"
Yast.import "Stage"
Yast.import "UI"
Yast.import "GetInstArgs"
Yast.import "Wizard"
Yast.import "Mode"
Yast.import "Language"
Yast.import "Report"
Yast.import "HTML"

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

      errors = []
      relnotes_map = products.each_with_object({}) do |product, all|
        relnotes = fetch_release_notes(product, Yast::Language.language, format)

        case relnotes
        when :missing
          log.info "No release notes were found for product #{product.short_name}" if relnotes.nil?
        when :error
          errors << product
        else
          all[product.short_name] = relnotes.content
        end
      end

      display_warning(errors) unless errors.empty?
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

      # Packages.Init is not called during upgrade
      return :auto if !Packages.init_called && !Stage.initial && !Mode.update

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
      # Don't rely on Product.with_status() here, use force_repos (bsc#1158287):
      # Otherwise we will only get products from the control file in the case
      # of online media, and that means only base products, no add-ons.
      all_products = Y2Packager::ProductReader.new.all_products(force_repos: true)
      return all_products.select { |p| p.status?(:selected, :installed) } unless Stage.initial
      selected = all_products.select { |p| p.status?(:selected) }
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

    # Fetch the release notes for a given product
    #
    # @param product [Y2Packager::Product]
    # @param user_lang [String] Preferred language (use current language as default)
    # @param format    [Symbol] Release notes format (use :txt as default)
    # @return [ReleaseNotes,Symbol] Release notes for product, language and format.
    #   :missing if release notes are not present and :error if something went wrong
    # @see Y2Packager::Product#release_notes
    def fetch_release_notes(product, user_lang, format)
      product.release_notes(user_lang, format) || :missing
    rescue Y2Packager::PackageFetchError, Y2Packager::PackageExtractionError => e
      log.warn "Could not download and extract the release notes package for '#{product.name}': #{e.inspect}"
      :error
    end

    # Displays
    def display_warning(products)
      # TRANSLATORS: 'product' stands for the product's name
      msg = HTML.Para(_("The release notes for the following products could not be retrieved:")) +
        HTML.List(products.map(&:display_name))
      Yast::Report.LongWarning(msg)
    end
  end
end

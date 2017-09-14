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

Yast.import "InstData"
Yast.import "Pkg"
Yast.import "Language"
Yast.import "Stage"
Yast.import "UI"
Yast.import "GetInstArgs"
Yast.import "Wizard"
Yast.import "Mode"

module Yast
  class InstDownloadReleaseNotesClient < Client
    include Yast::Logger

    # Download release notes for all selected and installed products
    #
    # @return true when successful
    def download_release_notes
      format = UI.TextMode ? :txt : :rtf

      products = Y2Packager::Product.with_status(*check_product_states)
      products.each do |product|
        relnotes = product.release_notes(format)
        if relnotes.nil?
          log.info "No release notes were found for product #{product.short_name}"
          next
        end
        InstData.release_notes[product.short_name] = relnotes
        InstData.downloaded_release_notes << product.short_name
      end
      return if InstData.release_notes.empty?

      UI.SetReleaseNotes(InstData.release_notes)
      Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
      true
    end

    # Set the UI content to show some progress.
    # FIXME: use a better title (reused existing texts because of text freeze)
    def init_ui
      Wizard.SetContents(_("Initializing"), Label(_("Initializing the installation...")),
        "", false, false)
    end

    def main
      textdomain "installation"

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

    # Get the list of product states which should be used for downloading
    # release notes.
    # @return [Array<Symbol>] list of states (:selected, :installed or :available)
    def check_product_states
      # installed may mean old (before upgrade) in initial stage
      # product may not yet be selected although repo is already added
      return [:selected, :installed] unless Stage.initial

      # if a product is already selected then use the selected products
      # otherwise use the available one(s)
      product_selected = Pkg.ResolvableProperties("", :product, "").any? do |p|
        p["status"] == :selected
      end

      product_selected ? [:selected] : [:available]
    end
  end
end

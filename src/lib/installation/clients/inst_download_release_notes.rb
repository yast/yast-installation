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
module Yast
  class InstDownloadReleaseNotesClient < Client
    include Yast::Logger

    # When cURL returns one of those codes, the download won't be retried
    # @see man curl
    CURL_GIVE_UP_RETURN_CODES = {
      5  => "Couldn't resolve proxy.",
      6  => "Couldn't resolve host.",
      7  => "Failed to connect to host.",
      28 => "Operation timeout."
    }.freeze

    # Download *url* to *filename*
    # May set InstData.stop_relnotes_download on download failure.
    #
    # @return [Boolean,nil] true: success, false: failure, nil: failure+dont retry
    def curl_download(url, filename, proxy_args:, max_time: 300)
      cmd = Builtins.sformat(
        "/usr/bin/curl --location --verbose --fail --max-time %6 --connect-timeout 15  %1 '%2' --output '%3' > '%4/%5' 2>&1",
        proxy_args,
        url,
        String.Quote(filename),
        String.Quote(Directory.logdir),
        "curl_log",
        max_time
      )
      ret = SCR.Execute(path(".target.bash"), cmd)
      log.info("#{cmd} returned #{ret}")
      reason = CURL_GIVE_UP_RETURN_CODES[ret]
      if !reason.nil?
        log.info "Communication with server failed (#{reason}), skipping further attempts."
        InstData.stop_relnotes_download = true
        return nil
      end
      ret == 0
    end

    # @return [String] to be interpolated in a .target.bash command, unquoted
    def curl_proxy_args
      proxy = ""
      # proxy should be set by inst_install_inf if set via Linuxrc
      Proxy.Read
      # Test if proxy works
      if Proxy.enabled
        # it is enough to test http proxy, release notes are downloaded via http
        proxy_ret = Proxy.RunTestProxy(
          Proxy.http,
          "",
          "",
          Proxy.user,
          Proxy.pass
        )

        if Ops.get_boolean(proxy_ret, ["HTTP", "tested"], true) == true &&
            Ops.get_integer(proxy_ret, ["HTTP", "exit"], 1) == 0
          user_pass = Proxy.user != "" ? "#{Proxy.user}:#{Proxy.pass}" : ""
          proxy = "--proxy #{Proxy.http}"
          proxy << " --proxy-user '#{user_pass}'" unless user_pass.empty?
        end
      end
      proxy
    end

    # Download of index of release notes for a specific product
    # @param url_base URL pointing to directory with the index
    # @param proxy the proxy URL to be passed to curl
    #
    # May set InstData.stop_relnotes_download on download failure.
    # @return [Array<String>,nil] filenames, nil if not found
    def download_release_notes_index(url_base, proxy)
      url_index = url_base + "/directory.yast"
      log.info("Index with available files: #{url_index}")
      filename = Builtins.sformat("%1/directory.yast", SCR.Read(path(".target.tmpdir")))
      # download the index with much shorter time-out
      ok = curl_download(url_index, filename, proxy_args: proxy, max_time: 30)

      if ok
        log.info("Release notes index downloaded successfully")
        index_file = File.read(filename)
        if index_file.nil? || index_file.empty?
          log.info("Release notes index empty, not filtering further downloads")
          return nil
        else
          rn_filter = index_file.split("\n")
          log.info("Index of RN files at the server: #{rn_filter}")
          return rn_filter
        end
      elsif ok.nil?
        return nil
      else
        log.info "Downloading index failed, trying all files according to selected language"
        return nil
      end
    end

    # Download release notes for all selected and installed products
    #
    # @return true when successful
    def download_release_notes
      filename_templ = UI.TextMode ? "/RELEASE-NOTES.%1.txt" : "/RELEASE-NOTES.%1.rtf"

      # Get proxy settings (if any)
      proxy = curl_proxy_args

      required_product_statuses = check_product_states
      log.info("Checking products in state: #{required_product_statuses}")
      products = Pkg.ResolvableProperties("", :product, "").select do |product|
        required_product_statuses.include? product["status"]
      end
      log.info("Products: #{products}")
      products.each do |product|
        if InstData.stop_relnotes_download
          log.info("Skipping release notes download due to previous download issues")
          break
        end
        if InstData.downloaded_release_notes.include? product["short_name"]
          log.info("Release notes for #{product["short_name"]} already downloaded, skipping...")
          next
        end
        url = product["relnotes_url"]
        log.debug("URL: #{url}")
        # protect from wrong urls
        if url.nil? || url.empty?
          log.warn("Skipping invalid URL #{url.inspect} for product #{product["short_name"]}")
          next
        end
        pos = url.rindex("/")
        if pos.nil?
          log.error "Broken URL for release notes: #{url}"
          next
        end
        url_base = url[0, pos]

        rn_filter = download_release_notes_index(url_base, proxy)
        if InstData.stop_relnotes_download
          log.info("Skipping release notes download due to previous download issues")
          break
        end

        url_template = url_base + filename_templ
        log.info("URL template: #{url_base}")
        [Language.language, Language.language[0..1], "en"].uniq.each do |lang|
          if !rn_filter.nil?
            filename = Builtins.sformat(filename_templ, lang)
            if !rn_filter.include?(filename[1..-1])
              log.info "File #{filename} not found in index, skipping attempt download"
              next
            end
          end
          url = Builtins.sformat(url_template, lang)
          log.info("URL: #{url}")
          # Where we want to store the downloaded release notes
          filename = Builtins.sformat("%1/relnotes",
            SCR.Read(path(".target.tmpdir")))

          if InstData.failed_release_notes.include?(url)
            log.info("Skipping download of already failed release notes at #{url}")
            next
          end

          # download release notes now
          ok = curl_download(url, filename, proxy_args: proxy)
          if ok
            log.info("Release notes downloaded successfully")
            InstData.release_notes[product["short_name"]] = SCR.Read(path(".target.string"), filename)
            InstData.downloaded_release_notes << product["short_name"]
            break
          elsif ok.nil?
            break
          else
            InstData.failed_release_notes << url
          end
        end
      end
      if !InstData.release_notes.empty?
        UI.SetReleaseNotes(InstData.release_notes)
        Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
      end
      true
    end

    # Set the UI content to show some progress.
    # FIXME: use a better title (reused existing texts because of text freeze)
    def init_ui
      Wizard.SetContents(_("Initializing"), Label(_("Initializing the installation...")),
        "", false, false)
    end

    def main
      Yast.import "UI"
      Yast.import "Language"
      Yast.import "Proxy"
      Yast.import "Directory"
      Yast.import "InstData"
      Yast.import "Stage"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"
      Yast.import "Mode"

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

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

    # Download all release notes mentioned in Product::relnotesurl_all
    #
    # @return true when successful
    def download_release_notes
      filename_templ = UI.TextMode ? "/RELEASE-NOTES.%1.txt" : "/RELEASE-NOTES.%1.rtf"

      # Get proxy settings (if any)
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

      # installed may mean old (before upgrade) in initial stage
      # product may not yet be selected although repo is already added
      required_product_statuses = Stage.initial ? [:selected, :available] : [:selected, :installed]
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
        url_template = url_base + filename_templ
        log.info("URL template: #{url_base}")
        [Language.language, Language.language[0..1], "en"].each do |lang|
          url = Builtins.sformat(url_template, lang)
          log.info("URL: #{url}")
          # Where we want to store the downloaded release notes
          filename = Builtins.sformat("%1/relnotes",
            SCR.Read(path(".target.tmpdir")))
          # download release notes now
          cmd = Builtins.sformat(
            "/usr/bin/curl --location --verbose --fail --max-time 300 --connect-timeout 15  %1 '%2' --output '%3' > '%4/%5' 2>&1",
            proxy,
            url,
            String.Quote(filename),
            String.Quote(Directory.logdir),
            "curl_log"
          )
          ret = SCR.Execute(path(".target.bash"), cmd)
          log.info("Downloading release notes: #{cmd} returned #{ret}")
          if ret == 0
            log.info("Release notes downloaded successfully")
            InstData.release_notes[product["short_name"]] = SCR.Read(path(".target.string"), filename)
            InstData.downloaded_release_notes << product["short_name"]
            break
          elsif CURL_GIVE_UP_RETURN_CODES.key? ret
            log.info "Communication with server for release notes download failed ( #{CURL_GIVE_UP_RETURN_CODES[ret]} ), skipping further attempts."
            InstData.stop_relnotes_download = true
            break
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
      Yast.import "Product"
      Yast.import "Language"
      Yast.import "Proxy"
      Yast.import "Directory"
      Yast.import "InstData"
      Yast.import "Stage"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"

      textdomain "installation"

      return :back if GetInstArgs.going_back

      init_ui

      download_release_notes
      :auto
    end
  end
end

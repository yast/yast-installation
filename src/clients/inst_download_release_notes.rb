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
    Yast.import "UI"
    Yast.import "Product"
    Yast.import "Language"
    Yast.import "Proxy"
    Yast.import "Directory"
    Yast.import "InstData"

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
        #it is enough to test http proxy, release notes are downloaded via http
        proxy_ret = Proxy.RunTestProxy(
          Proxy.http,
          "",
          "",
          Proxy.user,
          Proxy.pass
        )

        if Ops.get_boolean(proxy_ret, ["HTTP", "tested"], true) == true &&
            Ops.get_integer(proxy_ret, ["HTTP", "exit"], 1) == 0
          user_pass = Proxy.user != "" ?
            Ops.add(Ops.add(Proxy.user, ":"), Proxy.pass) :
            ""
          proxy = Ops.add(
            Ops.add("--proxy ", Proxy.http),
            user_pass != "" ?
              Ops.add(Ops.add(" --proxy-user '", user_pass), "'") :
              ""
          )
        end
      end

      products = Pkg.ResolvableDependencies("", :product, "").select { | product |
        product["status"] == :selected || product["status"] == :installed
      }
      Builtins.y2milestone("Products: %1", products)
      products.each { | product |
        url = product["relnotes_url"] #TODO: check
        Builtins.y2milestone("URL: %1", url)
        # protect from wrong urls
        if url == nil || url == ""
          Builtins.y2warning("Skipping relnotesurl '%1'", url)
          next false
        end
        pos = Builtins.findlastof(url, "/")
        if pos == nil
          Builtins.y2error("broken url for release notes: %1", url)
          next false
        end
        url_base = url[0, pos]
        Builtins.y2milestone("URL Base: %1", url_base)
        url_template = url_base + filename_templ
        Builtins.y2milestone("URL Template: %1", url_base)
        [Language.language, Builtins.substring(Language.language, 0, 2), "en"].each do | lang |
          Builtins.y2milestone("XX: %1", lang)
          url = Builtins.sformat(url_template, lang)
          Builtins.y2milestone("URL: %1", lang)
          # Where we want to store the downloaded release notes
          filename = Builtins.sformat("%1/relnotes",
            Convert.to_string(SCR.Read(path(".target.tmpdir"))))
          # download release notes now
          cmd = Ops.add(
            "/usr/bin/curl --location --verbose --fail --max-time 300 ",
            Builtins.sformat(
              "%1 %2 --output '%3' > '%4/%5' 2>&1",
              proxy,
              url,
              String.Quote(filename),
              String.Quote(Directory.logdir),
              "curl_log"
            )
          )
          Builtins.y2milestone("Downloading release notes: %1", cmd)
          ret = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))
          if ret == 0
            Builtins.y2milestone("Release notes downloaded successfully")
            InstData.release_notes[product["name"]] = SCR.Read(path(".target.string"), filename)
            break
          end
        end
      }
      if ! InstData.release_notes.empty?
        UI.SetReleaseNotes(InstData.release_notes)
        Wizard.ShowReleaseNotesButton(_("Re&lease Notes..."), "rel_notes")
      end
      true
    end

    def main
      download_release_notes
      :auto
    end
  end
end

Yast::InstDownloadReleaseNotesClient.new.main

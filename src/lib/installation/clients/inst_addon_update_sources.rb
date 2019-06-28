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

# File:  clients/inst_addon_update_sources.ycp
# Package:  yast2-installation
# Summary:  Add installation sources for online update, #163192
# Authors:  Martin Vidner <mvidner@suse.cz>
#
# Assumptions:
# - the sources will be saved afterwards
# (this means that running this client alone will not work)
module Yast
  class InstAddonUpdateSourcesClient < Client
    def main
      Yast.import "Pkg"
      textdomain "installation"

      Yast.import "GetInstArgs"
      Yast.import "PackageCallbacks"
      Yast.import "Popup"
      Yast.import "SourceManager"
      Yast.import "Report"
      Yast.import "Installation"
      Yast.import "String"

      Yast.include self, "packager/inst_source_dialogs.rb"

      return :auto if GetInstArgs.going_back # going backwards? # don't execute this once more

      @aliases = {}

      # feedback heading
      @heading = _("Add-on Product Installation")
      # feedback message
      @message = _("Reading packages available in the repositories...")

      # bugzilla #270899#c29
      Pkg.TargetInitialize(Installation.destdir)
      Pkg.TargetLoad
      Pkg.SourceStartManager(true)

      @knownUrls = KnownUrls()
      Builtins.y2milestone("sources known: %1", @knownUrls)
      @is_known = Builtins.listmap(@knownUrls) { |u| { u => true } }

      @updateUrls = UpdateUrls()
      Builtins.y2milestone("sources for updates: %1", @updateUrls)

      @addUrls = Builtins.filter(@updateUrls) do |url, _name|
        !Ops.get(@is_known, url, false)
      end
      Builtins.y2milestone("sources to add: %1", @addUrls)

      if @addUrls != {}
        Popup.ShowFeedback(@heading, @message)

        Builtins.foreach(@addUrls) do |url, name|
          again = true
          while again
            # BNC #557723: Repositories migh be created without access to network
            # Libzypp must not probe the repo

            alias_ = Ops.get(@aliases, url, "")
            if alias_ == ""
              # don't use spaces in alias (hard to use with zypper)
              alias_ = String.Replace(
                Ops.greater_than(Builtins.size(name), 0) ? name : url,
                " ",
                "-"
              )
            end

            repo_prop = {
              "enabled"     => true,
              "autorefresh" => true,
              "name"        => Ops.greater_than(Builtins.size(name), 0) ? name : url,
              "alias"       => alias_,
              "base_urls"   => [url],
              "prod_dir"    => "/"
            }

            srcid = Pkg.RepositoryAdd(repo_prop)
            Builtins.y2milestone("got %1 from creating %2/%3", srcid, url, name)

            # wrong srcid, must have failed
            if srcid == -1
              # popup error message
              # %1 represents the the error message details
              if Popup.YesNo(
                Builtins.sformat(
                  _(
                    "An error occurred while connecting to the server.\n" \
                      "Details: %1\n" \
                      "\n" \
                      "Try again?"
                  ),
                  Pkg.LastError
                )
              )
                # try again
                url = editUrl(url)
              else
                # abort
                again = false
              end

              # everything is ok
            else
              again = false
            end
          end
        end

        Popup.ClearFeedback
      end

      :auto

      # EOF
    end

    # @return the urls of known installation sources
    def KnownUrls
      src_ids = Pkg.SourceGetCurrent(
        true # enabled only?
      )
      urls = Builtins.maplist(src_ids) do |src_id|
        gendata = Pkg.SourceGeneralData(src_id)
        Ops.get_string(gendata, "url", "")
      end
      deep_copy(urls)
    end

    # @return the installation sources to be added
    def UpdateUrls
      urls = {}
      products = Pkg.ResolvableProperties("", :product, "")

      Builtins.foreach(products) do |p|
        Builtins.foreach(Ops.get_list(p, "update_urls", [])) do |u|
          # bnc #542792
          # Repository name must be generated from product details
          Ops.set(
            urls,
            u,
            Builtins.sformat(
              _("Updates for %1 %2"),
              Ops.get_locale(
                p,
                "display_name",
                Ops.get_locale(
                  p,
                  "name",
                  Ops.get_locale(p, "summary", _("Unknown Product"))
                )
              ),
              Ops.get_string(p, "version", "")
            )
          )
          # alias should be simple (bnc#768624)
          Ops.set(
            @aliases,
            u,
            String.Replace(
              Ops.add(
                "update-",
                Ops.get_string(
                  p,
                  "display_name",
                  Ops.get_string(p, "name", "repo")
                )
              ),
              " ",
              "-"
            )
          )
        end
      end

      deep_copy(urls)
    end
  end
end

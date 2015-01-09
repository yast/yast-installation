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

module Yast
  # This client loads the target and initializes the package manager.
  # Adds all sources defined in control file (software->extra_urls)
  # and stores them at the end.
  class InstExtrasourcesClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"

      textdomain "installation"

      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "PackageLock"
      Yast.import "ProductFeatures"
      # We need the constructor
      Yast.import "ProductControl"
      Yast.import "Installation"
      Yast.import "Icon"
      Yast.import "NetworkService"
      Yast.import "PackagesUI"
      Yast.import "Label"

      # local sources that have been attached under /mnt during upgrade
      @local_urls = {}

      # USB sources that were used during installation should be disabled (bnc#793709)
      @usb_sources = {}

      #////////////////////////////////////////

      if GetInstArgs.going_back # going backwards?
        return :auto # don't execute this once more
      end

      # autoyast mode, user cannot be asked
      if Mode.autoinst
        Builtins.y2milestone(
          "Skipping extra source configuration in AutoYaST mode"
        )
        return :auto
      end

      # bugzilla #263289
      if !InitializePackager()
        Builtins.y2error("Cannot connect to the Packager")
        return :auto
      end

      @already_registered = RegisteredUrls()

      @register_url = GetURLsToRegister(@already_registered)

      # fix local sources temporary attached under /mnt
      if Ops.greater_than(Builtins.size(@local_urls), 0)
        Builtins.foreach(@local_urls) do |srcid, url|
          new_url = Ops.add(
            "dir:",
            Builtins.substring(url, Ops.add(Builtins.find(url, "/mnt"), 4))
          )
          Builtins.y2milestone(
            "changing temporary url '%1' to '%2'",
            url,
            new_url
          )
          Pkg.SourceChangeUrl(srcid, new_url)
        end
        Pkg.SourceSaveAll
      end

      # disable USB sources
      if Ops.greater_than(Builtins.size(@usb_sources), 0)
        Builtins.foreach(@usb_sources) do |srcid, url|
          Builtins.y2milestone("disabling USB source %1", url)
          Pkg.SourceSetEnabled(srcid, false)
        end
        Pkg.SourceSaveAll
      end

      # any confirmed source to register?
      if Ops.greater_than(Builtins.size(@register_url), 0)
        # register (create) the sources
        @added_ids = RegisterRepos(@register_url)

        # synchronize the sources if any source has been added
        if Ops.greater_than(Builtins.size(@added_ids), 0)
          # If any source has been added, store the sources
          # bnc #440184
          Builtins.y2milestone(
            "Some (%1) sources have been added, storing them...",
            @added_ids
          )
          Pkg.SourceSaveAll
        end

        # check during upgrade whether the added repositories provide an upgrade for installed package
        # (openSUSE DVD does not contain all packages, packages from OSS repository might not have been upgraded,
        # see bnc#693230 for details)
        if Mode.update && Ops.greater_than(Builtins.size(@added_ids), 0)
          Builtins.y2milestone(
            "Checking whether there is and update provided by extra (non-update) repo..."
          )

          # network up?
          if NetworkService.isNetworkRunning
            # refresh the added repositories and load them
            if RefreshRepositories(@added_ids) && Pkg.SourceStartManager(true)
              # ignore update repositories - the updates will be installed later by online update
              @check_repos = Builtins.filter(@added_ids) do |repo|
                !IsUpdateRepo(repo)
              end

              if Ops.greater_than(Builtins.size(@check_repos), 0)
                UpgradeFrom(@check_repos)

                @upgrade_info = UpgradesAvailable(@check_repos)
                @upgrade_repos = Ops.get_list(@upgrade_info, "repositories", [])

                if Ops.greater_than(Builtins.size(@upgrade_repos), 0)
                  # popup message, list of repositores is appended to the text
                  @message = _(
                    "Package updates have been found in these additional repositories:"
                  ) + "\n\n"
                  Builtins.foreach(@upgrade_repos) do |repo|
                    repo_info = Pkg.SourceGeneralData(repo)
                    @message = Ops.add(
                      @message,
                      Builtins.sformat(
                        "%1 (%2)\n",
                        Ops.get_string(repo_info, "name", ""),
                        Ops.get_string(repo_info, "url", "")
                      )
                    )
                  end

                  # yes/no popup question
                  @message = Ops.add(
                    Ops.add(@message, "\n\n"),
                    _(
                      "Start the software manager to check and install the updates?"
                    )
                  )

                  @package_list = Builtins.mergestring(
                    Ops.get_list(@upgrade_info, "packages", []),
                    "\n"
                  )

                  if InstallPackages(@message, @package_list)
                    # start the software manager
                    @ui = PackagesUI.RunPackageSelector(
                       "mode" => :summaryMode 
                    )
                    Builtins.y2milestone("Package manager returned: %1", @ui)

                    if @ui == :accept
                      # install the packages
                      Builtins.y2milestone("Installing packages")
                      WFM.call("inst_rpmcopy")
                    end
                  else
                    Builtins.y2milestone(
                      "Skipping installation of the available updates"
                    )
                  end
                else
                  Builtins.y2milestone(
                    "Everything OK, no available update found"
                  )
                end

                RevertUpgradeFrom(@check_repos)
              end
            else
              Builtins.y2warning("Could not load new repositories")
            end
          else
            Builtins.y2milestone(
              "Network is not running, skipping available updates check"
            )
          end
        end
      end

      :auto 

      # EOF
    end

    # Returns list of maps of repositories to register. See bnc #381360.
    #
    # @param [Array<String>] registered URLs of already registered repositories (they will be ignored to not register the same repository one more)
    # @return [Array<Hash>] of URLs to register
    def GetURLsToRegister(registered)
      registered = deep_copy(registered)
      urls_from_control_file = Convert.convert(
        ProductFeatures.GetFeature("software", "extra_urls"),
        :from => "any",
        :to   => "list <map>"
      )

      if urls_from_control_file == nil
        Builtins.y2milestone(
          "Empty or errorneous software/extra_urls: %1",
          urls_from_control_file
        )
        return []
      end

      urls_from_control_file = Builtins.filter(urls_from_control_file) do |one_url|
        if Builtins.contains(registered, Ops.get_string(one_url, "baseurl", ""))
          Builtins.y2milestone(
            "Already registered: %1",
            Ops.get_string(one_url, "baseurl", "")
          )
          next false
        end
        true
      end

      Builtins.y2milestone(
        "Repositories to register: %1",
        urls_from_control_file
      )
      deep_copy(urls_from_control_file)
    end

    # Register the installation sources in offline mode (no network connection required).
    # The repository metadata will be downloaded by sw_single (or another yast module) when the repostory is enabled
    #
    # @param list <map> list of the sources to register
    # @return [Array<Fixnum>] list of created source IDs
    def RegisterRepos(url_list)
      url_list = deep_copy(url_list)
      ret = []

      Builtins.foreach(url_list) do |new_url|
        if Ops.get_string(new_url, "baseurl", "") == nil ||
            Ops.get_string(new_url, "baseurl", "") == ""
          Builtins.y2error(
            "Cannot use repository: %1, no 'baseurl' defined",
            new_url
          )
          next
        end
        repo_prop = {}
        # extra repos are disabled by default
        Ops.set(
          repo_prop,
          "enabled",
          Ops.get_boolean(new_url, "enabled", false)
        )
        Ops.set(
          repo_prop,
          "autorefresh",
          Ops.get_boolean(new_url, "autorefresh", true)
        )
        # repository name (try) name, alias, (fallback) baseurl
        Ops.set(
          repo_prop,
          "name",
          Ops.get_string(
            new_url,
            "name",
            Ops.get_string(
              new_url,
              "alias",
              Ops.get_string(new_url, "baseurl", "")
            )
          )
        )
        # repository alias (try) alias, (fallback) baseurl
        Ops.set(
          repo_prop,
          "alias",
          Ops.get_string(
            new_url,
            "alias",
            Ops.get_string(new_url, "baseurl", "")
          )
        )
        Ops.set(
          repo_prop,
          "base_urls",
          [Ops.get_string(new_url, "baseurl", "")]
        )
        if Builtins.haskey(new_url, "prod_dir")
          Ops.set(
            repo_prop,
            "prod_dir",
            Ops.get_string(new_url, "prod_dir", "/")
          )
        end
        if Builtins.haskey(new_url, "priority")
          Ops.set(
            repo_prop,
            "priority",
            Builtins.tointeger(Ops.get_integer(new_url, "priority", 99))
          )
        end
        new_repo_id = Pkg.RepositoryAdd(repo_prop)
        if new_repo_id != nil && Ops.greater_or_equal(new_repo_id, 0)
          Builtins.y2milestone(
            "Registered extra repository: %1: %2",
            new_repo_id,
            repo_prop
          )
          ret = Builtins.add(ret, new_repo_id)
        else
          Builtins.y2error("Cannot register: %1", repo_prop)
        end
      end 

      deep_copy(ret)
    end

    # Returns list of already registered repositories.
    #
    # @return [Array<String>] of registered repositories
    def RegisteredUrls
      # get all registered installation sources
      srcs = Pkg.SourceGetCurrent(false)

      ret = []
      Builtins.foreach(srcs) do |src|
        general = Pkg.SourceGeneralData(src)
        url = Ops.get_string(general, "url", "")
        ret = Builtins.add(ret, url) if url != nil && url != ""
        if Mode.update && Builtins.regexpmatch(url, "^dir:[/]+mnt[/]+")
          Ops.set(@local_urls, src, url)
        end
        # check for USB sources which should be disabled
        if Builtins.issubstring(url, "device=/dev/disk/by-id/usb-")
          Ops.set(@usb_sources, src, url)
        end
      end 

      # remove duplicates
      ret = Builtins.toset(ret)

      Builtins.y2milestone("Registered sources: %1", ret)

      Builtins.y2milestone(
        "Registered local sources under /mnt: %1",
        @local_urls
      )

      Builtins.y2milestone("Registered USB sources: %1", @usb_sources)

      deep_copy(ret)
    end

    # Initialize the package manager
    # needed for registered sources and products
    def InitializePackager
      return false if !PackageLock.Check

      # to find out which sources have been already registered
      Pkg.SourceStartManager(false)

      # to initialize target because of installed products
      Pkg.TargetInit(Installation.destdir, false) == true
    end

    # refresh the requested repositories
    # returns true on success
    def RefreshRepositories(repos)
      repos = deep_copy(repos)
      ret = true

      Builtins.y2milestone("Refreshing repositories %1", repos)
      Builtins.foreach(repos) { |repo| ret = ret && Pkg.SourceRefreshNow(repo) }

      Builtins.y2milestone("Refresh succeeded: %1", ret)

      ret
    end

    # is the repository an update repo?
    def IsUpdateRepo(repo)
      Builtins.y2milestone(
        "Checking whether repository %1 is an update repo...",
        repo
      )
      ret = false

      # check if there is a patch available in the repository
      Builtins.foreach(Pkg.ResolvableProperties("", :patch, "")) do |patch|
        if Ops.get_integer(patch, "source", -1) == repo
          Builtins.y2milestone(
            "Found patch %1 in the repository",
            Ops.get_string(patch, "name", "")
          )
          ret = true
          raise Break
        end
      end

      Builtins.y2milestone("Repository %1 is update repo: %2", repo, ret)

      ret
    end

    # mark the repositories for upgrade, run the solver
    def UpgradeFrom(repos)
      repos = deep_copy(repos)
      Builtins.foreach(repos) do |repo|
        Builtins.y2milestone("Adding upgrade repo %1", repo)
        Pkg.AddUpgradeRepo(repo)
      end

      Pkg.PkgSolve(true)

      nil
    end

    # revert the upgrading repos, reset package selection
    def RevertUpgradeFrom(repos)
      repos = deep_copy(repos)
      Builtins.foreach(repos) do |repo|
        Builtins.y2milestone("Removing upgrade repo %1", repo)
        Pkg.RemoveUpgradeRepo(repo)
      end

      Pkg.PkgApplReset
      Pkg.PkgReset

      nil
    end

    # check if there is a selected package in the requested repositories
    # returns list of repositories providing an update (repo IDs)
    def UpgradesAvailable(repos)
      repos = deep_copy(repos)
      ret = []
      packages = []

      Builtins.foreach(Pkg.ResolvableProperties("", :package, "")) do |pkg|
        source = Ops.get_integer(pkg, "source", -1)
        if Ops.get_symbol(pkg, "status", :none) == :selected &&
            Builtins.contains(repos, source)
          package = Builtins.sformat(
            "%1-%2.%3",
            Ops.get_string(pkg, "name", ""),
            Ops.get_string(pkg, "version", ""),
            Ops.get_string(pkg, "arch", "")
          )
          Builtins.y2milestone("Found upgrade to install: %1", package)
          packages = Builtins.add(packages, package)

          ret = Builtins.add(ret, source) if !Builtins.contains(ret, source)
        end
      end

      Builtins.y2milestone("Upgrades found in repositories: %1", ret)

      { "repositories" => ret, "packages" => packages }
    end

    # ask user whether to install available package updates
    # returns true after confirming
    def InstallPackages(msg, details)
      button_box = ButtonBox(
        PushButton(
          Id(:yes),
          Opt(:default, :okButton, :key_F10),
          Label.YesButton
        ),
        PushButton(Id(:no), Opt(:cancelButton, :key_F9), Label.NoButton)
      )

      dialog = HBox(
        HSpacing(0.5),
        Top(MarginBox(1, 1, Icon.Image("question", {}))),
        VBox(
          Left(Label(msg)),
          VSpacing(0.5),
          # check box
          Left(
            CheckBox(Id(:show), Opt(:notify), _("Show &package updates"), false)
          ),
          ReplacePoint(Id(:info), Empty()),
          button_box
        ),
        HSpacing(2)
      )

      UI.OpenDialog(Opt(:decorated), dialog)

      r = nil
      while r != :yes && r != :no && r != :cancel
        r = UI.UserInput

        if r == :show
          if UI.QueryWidget(Id(:show), :Value) == true
            UI.ReplaceWidget(Id(:info), RichText(Opt(:plainText), details))
          else
            UI.ReplaceWidget(Id(:info), Empty())
          end
        end
      end

      UI.CloseDialog

      Builtins.y2milestone("User input: %1", r)

      r == :yes
    end
  end
end

Yast::InstExtrasourcesClient.new.main

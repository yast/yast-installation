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

require "fileutils"

module Yast
  class InstUpgradeUrlsClient < Client
    include Yast::Logger

    def main
      Yast.import "Pkg"
      Yast.import "UI"
      # FATE #301785: Distribution upgrade should offer
      # existing extra installation repository as Add-On

      Yast.import "Installation"
      Yast.import "FileUtils"
      Yast.import "Stage"
      Yast.import "GetInstArgs"
      Yast.import "Mode"
      Yast.import "Wizard"
      Yast.import "Progress"
      Yast.import "Label"
      Yast.import "NetworkService"
      Yast.import "Popup"
      Yast.import "AddOnProduct"
      Yast.import "Report"
      Yast.import "PackageCallbacks"

      textdomain "installation"

      @ret = :next
      @ret = :back if GetInstArgs.going_back

      @test_mode = false

      @do_not_remove = 0

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        Builtins.y2milestone("Args: %1", WFM.Args)
        @test_mode = true if WFM.Args(0) == "test"
      end

      if @test_mode
        Builtins.y2milestone("Test mode")
      else
        if !Stage.initial
          Builtins.y2milestone("Not an initial stage")
          return @ret
        end
        if !Mode.update
          Builtins.y2milestone("Not an udpate mode")
          return @ret
        end
      end

      @dir_new = Builtins.sformat("%1/etc/zypp/repos.d/", Installation.destdir)

      @system_urls = []

      @already_registered_repos = []

      @REPO_REMOVED = "removed"
      @REPO_ENABLED = "enabled"
      @REPO_DISABLED = "disabled"

      @repos_to_remove = []

      # repositories for removal (the repo files will be removed directly)
      @repo_files_to_remove = []

      @repos_to_add = []

      @id_to_url = {}

      # bnc #308763
      @repos_to_add_disabled = []

      @urls = []

      @id_to_name = {}

      @status_map = {
        # TRANSLATORS: Table item status (repository)
        @REPO_REMOVED  => _(
          "Removed"
        ),
        # TRANSLATORS: Table item status (repository)
        @REPO_ENABLED  => _(
          "Enabled"
        ),
        # TRANSLATORS: Table item status (repository)
        @REPO_DISABLED => _(
          "Disabled"
        )
      }

      # for testing purpose
      Wizard.CreateDialog if Mode.normal

      Progress.NextStage

      ReadZyppRepositories()

      Progress.NextStage

      @continue_processing = false

      if @system_urls != nil && @system_urls != []
        @continue_processing = true
        # initialize zypp
        Pkg.TargetInitialize(Installation.destdir)
        # bnc #429080
        Pkg.TargetLoad
        # Note: does not work when a repository is already registered
        # in pkg-bindings!
        Pkg.SourceStartManager(false)

        @current_repos_list = Pkg.SourceGetCurrent(
          false # not only enabled
        )
        Builtins.y2milestone(
          "Currently registered repos: %1",
          @current_repos_list
        )

        Builtins.foreach(@current_repos_list) do |one_id|
          source_data = Pkg.SourceGeneralData(one_id)
          Ops.set(source_data, "media", one_id)
          @already_registered_repos = Builtins.add(
            @already_registered_repos,
            source_data
          )
        end
      end

      # bnc #400823
      @do_not_remove = Ops.get(Pkg.SourceGetCurrent(false), 0, 0)

      FillUpURLs()
      RemoveInstallationReposFromUpgrededSystemOnes()

      Progress.NextStage
      Progress.Finish

      if @already_registered_repos == nil ||
          Ops.less_than(Builtins.size(@already_registered_repos), 1)
        Builtins.y2milestone("No repositories found")
        @continue_processing = false
      elsif @urls == nil || Ops.less_than(Builtins.size(@urls), 1)
        Builtins.y2milestone("No repositories to offer")
        @continue_processing = false
      end

      if @continue_processing
        @ret = HandleOldSources()
        @ret = AddOrRemoveRepositories() if @ret == :next
      end

      # for testing purpose
      if Mode.normal
        Pkg.SourceSaveAll if @ret == :next
        Wizard.CloseDialog
      end

      Builtins.y2milestone("Returning %1", @ret)
      @ret
    end

    def ReadZyppRepositories
      # New-type URLs
      @system_urls = Convert.convert(
        SCR.Read(path(".zypp_repos"), @dir_new),
        :from => "any",
        :to   => "list <map>"
      )

      if @system_urls == nil || @system_urls == []
        Builtins.y2milestone("No zypp repositories on the target")
      else
        Builtins.y2milestone("URLs: %1", @system_urls)
      end

      nil
    end

    def CreateListTableUI
      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Previously Used Repositories"),
        VBox(
          # TRANSLATORS: dialog text, possibly multiline,
          # Please, do not use more than 50 characters per line.
          Left(
            Label(
              _(
                "These repositories were found on the system\nyou are upgrading:"
              )
            )
          ),
          Table(
            Id("table_of_repos"),
            Opt(:notify, :keepSorting),
            Header(
              # TRANSLATORS: Table header item
              _("Current Status"),
              # TRANSLATORS: Table header item
              _("Repository"),
              # TRANSLATORS: Table header item
              _("URL")
            ),
            []
          ),
          Left(
            HBox(
              # TRANSLATORS: Push button
              PushButton(Id(:edit), _("&Change...")),
              HSpacing(1),
              # TRANSLATORS: Push button
              PushButton(Id(:toggle), _("&Toggle Status")),
              HStretch()
            )
          )
        ),
        # TRANSLATORS: help text 1/3
        _(
          "<p>Here you see all software repositories found\non the system you are upgrading. Enable the ones you want to include in the upgrade process.</p>"
        ) +
          # TRANSLATORS: help text 2/3
          _(
            "<p>To enable, remove or disable an URL, click on the\n<b>Toggle Status</b> button or double-click on the respective table item.</p>"
          ) +
          # TRANSLATORS: help text 3/3
          _("<p>To change the URL, click on the <b>Change...</b> button.</p>"),
        true,
        true
      )
      Wizard.SetTitleIcon("yast-sw_source")

      nil
    end

    def RedrawListTableUI
      currentitem = Convert.to_integer(
        UI.QueryWidget(Id("table_of_repos"), :CurrentItem)
      )

      counter = -1
      items = Builtins.maplist(@urls) do |one_url|
        counter = Ops.add(counter, 1)
        # one_url already has "id" and some items might be deleted
        # looking to id_to_name is done via the original key
        Ops.set(
          @id_to_name,
          Ops.get_string(one_url, "id", Builtins.sformat("ID: %1", counter)),
          Ops.get_locale(one_url, "name", _("Unknown"))
        )
        Item(
          Id(counter),
          Ops.get(
            @status_map,
            Ops.get_string(one_url, "new_status", @REPO_REMOVED),
            _("Unknown")
          ),
          Ops.get_locale(
            # TRANSLATORS: Fallback name for a repository
            one_url,
            "name",
            _("Unknown")
          ),
          Ops.get_string(one_url, "url", "")
        )
      end

      # bnc #390612
      items = Builtins.sort(items) do |a, b|
        Ops.less_than(Ops.get_string(a, 2, ""), Ops.get_string(b, 2, ""))
      end

      UI.ChangeWidget(Id("table_of_repos"), :Items, items)

      if currentitem != nil
        UI.ChangeWidget(Id("table_of_repos"), :CurrentItem, currentitem)
      end

      enable_buttons = Ops.greater_than(Builtins.size(items), 0)
      UI.ChangeWidget(Id(:edit), :Enabled, enable_buttons)
      UI.ChangeWidget(Id(:toggle), :Enabled, enable_buttons)

      nil
    end

    # 'removed'	-> currently not enabled
    # 'enabled'	-> currently added as enabled
    # 'disabled'	-> currently added as disabled
    def FindCurrentRepoStatus(_alias)
      if _alias == "" || _alias == nil
        Builtins.y2error("alias URL not defined!")
        return @REPO_REMOVED
      end

      ret = @REPO_REMOVED

      Builtins.foreach(@already_registered_repos) do |one_url|
        if _alias == Ops.get_string(one_url, "alias", "-A-")
          ret = Ops.get_boolean(one_url, @REPO_ENABLED, false) == true ? @REPO_ENABLED : @REPO_DISABLED
          raise Break
        end
      end

      ret
    end

    def FindURLName(id)
      if id == "" || id == nil
        Builtins.y2error("Base URL not defined!")
        return nil
      end

      ret = nil

      Builtins.foreach(@urls) do |one_url|
        if id == Ops.get_string(one_url, "id", "-A-") &&
            Ops.get_string(one_url, "name", "") != ""
          ret = Ops.get_string(one_url, "name", "")
          raise Break
        end
      end

      ret
    end

    def FindURLType(id)
      if id == "" || id == nil
        Builtins.y2error("Base URL not defined!")
        return ""
      end

      ret = ""

      Builtins.foreach(@urls) do |one_url|
        if id == Ops.get_string(one_url, "id", "-A-") &&
            Ops.get_string(one_url, "type", "") != ""
          ret = Ops.get_string(one_url, "type", "")
          raise Break
        end
      end

      ret
    end

    def EditItem(currentitem)
      if currentitem == nil || Ops.less_than(currentitem, 0)
        Builtins.y2error("Cannot edit item: %1", currentitem)
        return
      end

      url = Ops.get_string(@urls, [currentitem, "url"], "")
      min_width = Builtins.size(url)

      UI.OpenDialog(
        VBox(
          # TRANSLATORS: textentry
          MinWidth(min_width, TextEntry(Id(:url), _("&Repository URL"), url)),
          VSpacing(1),
          ButtonBox(
            PushButton(
              Id(:ok),
              Opt(:default, :okButton, :key_F10),
              Label.OKButton
            ),
            PushButton(
              Id(:cancel),
              Opt(:cancelButton, :key_F9),
              Label.CancelButton
            )
          )
        )
      )

      ret = UI.UserInput
      url = Convert.to_string(UI.QueryWidget(Id(:url), :Value))
      UI.CloseDialog

      return if ret == :cancel

      Ops.set(@urls, [currentitem, "url"], url)

      nil
    end

    def FillUpURLs
      @urls = []

      # If some new (since 10.3 Alpha?) URLs found, use only them
      if @system_urls != nil && @system_urls != []
        Builtins.foreach(@system_urls) do |one_url_map|
          # bnc #300901
          enabled = nil
          # mapping url (zypp-based) keys to keys used in pkg-bindings
          if Ops.is_integer?(Ops.get_integer(one_url_map, @REPO_ENABLED, 0))
            enabled = Ops.get_integer(one_url_map, @REPO_ENABLED, 0) == 1
          elsif Ops.is_string?(Ops.get_string(one_url_map, @REPO_ENABLED, "0"))
            enabled = Ops.get_string(one_url_map, @REPO_ENABLED, "0") == "1"
          elsif Ops.is_boolean?(
              Ops.get_boolean(one_url_map, @REPO_ENABLED, false)
            )
            enabled = Ops.get_boolean(one_url_map, @REPO_ENABLED, false)
          end
          # bnc #387261
          autorefresh = true
          # mapping url (zypp-based) keys to keys used in pkg-bindings
          if Ops.is_integer?(Ops.get_integer(one_url_map, "autorefresh", 0))
            autorefresh = Ops.get_integer(one_url_map, "autorefresh", 0) == 1
          elsif Ops.is_string?(Ops.get_string(one_url_map, "autorefresh", "0"))
            autorefresh = Ops.get_string(one_url_map, "autorefresh", "0") == "1"
          elsif Ops.is_boolean?(
              Ops.get_boolean(one_url_map, "autorefresh", false)
            )
            autorefresh = Ops.get_boolean(one_url_map, "autorefresh", false)
          end
          keeppackages = true
          # mapping url (zypp-based) keys to keys used in pkg-bindings
          if Ops.is_integer?(Ops.get_integer(one_url_map, "keeppackages", 0))
            keeppackages = Ops.get_integer(one_url_map, "keeppackages", 0) == 1
          elsif Ops.is_string?(Ops.get_string(one_url_map, "keeppackages", "0"))
            keeppackages = Ops.get_string(one_url_map, "keeppackages", "0") == "1"
          elsif Ops.is_boolean?(
              Ops.get_boolean(one_url_map, "keeppackages", false)
            )
            keeppackages = Ops.get_boolean(one_url_map, "keeppackages", false)
          end
          new_url_map = {
            "autorefresh"  => autorefresh,
            "alias"        => Ops.get_string(
              one_url_map,
              "id",
              Ops.get_string(one_url_map, "baseurl", "")
            ),
            "url"          => Ops.get(one_url_map, "baseurl"),
            "name"         => Ops.get_string(one_url_map, "name", "") == "" ?
              Ops.get_string(one_url_map, "id", "") :
              Ops.get_string(one_url_map, "name", ""),
            @REPO_ENABLED  => enabled,
            "keeppackages" => keeppackages
          }
          if Builtins.haskey(one_url_map, "priority")
            Ops.set(
              new_url_map,
              "priority",
              Ops.get_integer(one_url_map, "priority", 99)
            )
          end
          # store the repo-type as well
          if Ops.get_string(one_url_map, "type", "") != ""
            Ops.set(
              new_url_map,
              "type",
              Ops.get_string(one_url_map, "type", "")
            )
          end
          @urls = Builtins.add(@urls, new_url_map)
        end
      end

      id = -1
      url_alias = ""

      @urls = Builtins.maplist(@urls) do |one_url|
        id = Ops.add(id, 1)
        # unique ID
        Ops.set(one_url, "id", Builtins.sformat("ID: %1", id))
        # BNC #429059
        if Builtins.haskey(one_url, "alias") && Ops.get(one_url, "alias") != nil
          url_alias = Builtins.sformat(
            "%1",
            Ops.get_string(one_url, "alias", "")
          )
          Ops.set(one_url, "new_status", FindCurrentRepoStatus(url_alias))
        else
          Builtins.y2warning("No 'alias' defined: %1", one_url)
          Ops.set(one_url, "new_status", @REPO_REMOVED)
        end
        Ops.set(
          one_url,
          "initial_url_status",
          Ops.get_string(one_url, "new_status", @REPO_REMOVED)
        )
        deep_copy(one_url)
      end

      nil
    end

    # Function removes repositories already registered by the installation
    # from list of urls found on the system.
    def RemoveInstallationReposFromUpgrededSystemOnes
      # Works only for the very first registered (installation) repo
      found = false

      # All already registered repos
      Builtins.foreach(@already_registered_repos) do |one_registered_repo|
        if Ops.get_boolean(one_registered_repo, @REPO_ENABLED, true) == false
          next
        end
        raise Break if found == true
        found = true
        # if an installation repository is disabled, skip it
        if Ops.get_boolean(one_registered_repo, @REPO_ENABLED, true) == false
          Builtins.y2milestone(
            "Repo %1 is not enabled, skipping",
            Ops.get(
              one_registered_repo,
              "url",
              Ops.get(one_registered_repo, "media")
            )
          )
          next
        end
        registered_url = Ops.get_string(one_registered_repo, "url", "-A-")
        registered_name = Ops.get_string(one_registered_repo, "name", "-A-")
        registered_dir = Ops.get_string(one_registered_repo, "path", "/")
        # Remove them from repos being offered to user to enable/disable them
        # Don't handle them at all, they have to stay untouched
        # See bnc #360109
        @urls = Builtins.filter(@urls) do |one_from_urls|
          one_url = Ops.get_string(one_from_urls, "url", "-B-")
          one_name = Ops.get_string(one_from_urls, "name", "-B-")
          one_dir = Ops.get_string(one_from_urls, "path", "/")
          if registered_url == one_url && registered_name == one_name &&
              registered_dir == one_dir
            Builtins.y2milestone(
              "The same product (url) already in use, not handling it %1",
              one_registered_repo
            )
            next false
          else
            next true
          end
        end
      end

      nil
    end

    # BNC #583155: Removed/Enabled/Disabled
    # Toggled this way: R/E/D/R/E/D/...
    def ToggleStatus(repo_map)
      repo_map = deep_copy(repo_map)
      status = Ops.get_string(repo_map, "new_status", @REPO_REMOVED)

      if status == @REPO_REMOVED
        status = @REPO_ENABLED
      elsif status == @REPO_ENABLED
        status = @REPO_DISABLED
        # disabled
      else
        status = @REPO_REMOVED
      end

      status
    end

    def HandleOldSources
      Builtins.y2milestone("Offering: %1", @urls)
      Builtins.y2milestone("Already registered: %1", @already_registered_repos)

      CreateListTableUI()
      RedrawListTableUI()

      ret = :next
      ui_ret = nil

      while true
        ui_ret = UI.UserInput

        ui_ret = :toggle if ui_ret == "table_of_repos"

        if ui_ret == :toggle
          currentitem = Convert.to_integer(
            UI.QueryWidget(Id("table_of_repos"), :CurrentItem)
          )
          if currentitem != nil
            # BNC #583155: Removed/Enabled/Disabled
            Ops.set(
              @urls,
              [currentitem, "new_status"],
              ToggleStatus(Ops.get(@urls, currentitem, {}))
            )
            RedrawListTableUI()
          end
          next
        elsif ui_ret == :next
          ret = :next
          break
        elsif ui_ret == :back
          ret = :back
          break
        elsif ui_ret == :abort && Popup.ConfirmAbort(:painless)
          ret = :abort
          break
        elsif ui_ret == :edit
          currentitem = Convert.to_integer(
            UI.QueryWidget(Id("table_of_repos"), :CurrentItem)
          )
          EditItem(currentitem)
          RedrawListTableUI()
        else
          Builtins.y2error("Unknown UI input: %1", ui_ret)
        end
      end

      ret
    end

    def NetworkRunning
      ret = false

      while true
        if NetworkService.isNetworkRunning
          ret = true
          break
        end

        # Network is not running
        if !Popup.AnyQuestion(
            # TRANSLATORS: popup header
            _("Network is not Configured"),
            # TRANSLATORS: popup question
            _(
              "Remote repositories require an Internet connection.\nConfigure it?"
            ),
            Label.YesButton,
            Label.NoButton,
            :yes
          )
          Builtins.y2milestone("User decided not to setup the network")
          ret = false
          break
        end

        Builtins.y2milestone("User wants to setup the network")
        # Call network-setup client
        netret = WFM.call("inst_lan", [GetInstArgs.argmap.merge({"skip_detection" => true})])

        if netret == :abort
          Builtins.y2milestone("Aborting the network setup")
          break
        end
      end

      ret
    end

    def SetAddRemoveSourcesUI
      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Previously Used Repositories"),
        VBox(
          # TRANSLATORS: Progress text
          Label(_("Adding and removing repositories..."))
        ),
        # TRANSLATORS: help text
        _("<p>Repositories are being added and removed.</p>"),
        false,
        false
      )
      Wizard.SetTitleIcon("yast-sw_source")

      nil
    end

    def SetAddRemoveSourcesProgress
      actions_todo = []
      actions_doing = []

      steps_nr = 0

      if Ops.greater_than(Builtins.size(@repos_to_remove), 0)
        Builtins.y2milestone("Remove %1 repos", @repos_to_remove)
        actions_todo = Builtins.add(
          actions_todo,
          _("Remove unused repositories")
        )
        actions_doing = Builtins.add(
          actions_doing,
          _("Removing unused repositories...")
        )
        steps_nr = Ops.add(steps_nr, Builtins.size(@repos_to_remove))
      end

      if Ops.greater_than(Builtins.size(@repos_to_add), 0)
        Builtins.y2milestone("Add %1 enabled repos", @repos_to_add)
        actions_todo = Builtins.add(actions_todo, _("Add enabled repositories"))
        actions_doing = Builtins.add(
          actions_doing,
          _("Adding enabled repositories...")
        )
        steps_nr = Ops.add(steps_nr, Builtins.size(@repos_to_add))
      end

      if Ops.greater_than(Builtins.size(@repos_to_add_disabled), 0)
        Builtins.y2milestone("Add %1 disabled repos", @repos_to_add_disabled)
        actions_todo = Builtins.add(
          actions_todo,
          _("Add disabled repositories")
        )
        actions_doing = Builtins.add(
          actions_doing,
          _("Adding disabled repositories...")
        )
        steps_nr = Ops.add(steps_nr, Builtins.size(@repos_to_add_disabled))
      end

      Progress.New(
        # TRANSLATORS: dialog caption
        _("Previously Used Repositories"),
        _("Adding and removing repositories..."),
        steps_nr,
        actions_todo,
        actions_doing,
        # TRANSLATORS: help text
        _("<p>Repositories are being added and removed.</p>")
      )

      nil
    end

    # See bnc #309317
    def GetUniqueAlias(alias_orig)
      alias_orig = "" if alias_orig == nil

      # all current aliases
      aliases = Builtins.maplist(Pkg.SourceGetCurrent(false)) do |i|
        info = Pkg.SourceGeneralData(i)
        Ops.get_string(info, "alias", "")
      end

      # default
      _alias = alias_orig

      # repository alias must be unique
      # if it already exists add "_<number>" suffix to it
      idx = 1
      while Builtins.contains(aliases, _alias)
        _alias = Builtins.sformat("%1_%2", alias_orig, idx)
        idx = Ops.add(idx, 1)
      end

      if alias_orig != _alias
        Builtins.y2milestone("Alias '%1' changed to '%2'", alias_orig, _alias)
      end

      _alias
    end

    def AdjustRepoSettings(new_repo, id)
      if id == nil || id == ""
        Builtins.y2error("Undefined ID: %1", id)
        return
      end

      Builtins.foreach(@urls) do |one_url|
        if Ops.get_string(one_url, "id", "") == id
          Builtins.y2milestone("Matching: %1", one_url)

          # alias needs to be unique
          # bnc #309317
          #
          # alias is taken from the system first
          # bnc #387261
          #
          Ops.set(
            new_repo.value,
            "alias",
            GetUniqueAlias(Ops.get_string(one_url, "alias", ""))
          )

          Builtins.foreach(["autorefresh", "gpgcheck", "keeppackages"]) do |key|
            if Builtins.haskey(one_url, key)
              Ops.set(new_repo.value, key, Ops.get_boolean(one_url, key, true))
            end
          end

          if Builtins.haskey(one_url, "priority")
            Ops.set(
              new_repo.value,
              "priority",
              Ops.get_integer(one_url, "priority", 99)
            )
          end

          raise Break
        end
      end

      nil
    end

    # Removes selected repositories
    def IUU_RemoveRepositories
      if !@repo_files_to_remove.empty?
        backup_dir = File.join(Installation.destdir, "var/adm/backup/upgrade/zypp/repos.d")

        ::FileUtils.mkdir_p(backup_dir) unless File.exist?(backup_dir)

        @repo_files_to_remove.each do |repo|
          log.info "Removing repository: #{repo}"

          path = File.join(Installation.destdir, "etc/zypp/repos.d", "#{repo["alias"]}.repo")
          if File.exist?(path)
            log.info "Moving file #{path} to #{backup_dir}"
            ::FileUtils.mv(path, backup_dir)
          end
        end

        # force reloading the libzypp repomanager to notice the removed files
        Pkg.TargetFinish
        Pkg.TargetInitialize(Installation.destdir)
        Pkg.TargetLoad
      end

      return if Builtins.size(@repos_to_remove) == 0

      Progress.Title(_("Removing unused repositories..."))
      Progress.NextStage

      Builtins.y2milestone("Deleting repos: %1", @repos_to_remove)
      Builtins.foreach(@repos_to_remove) do |one_id|
        Progress.NextStep
        Pkg.SourceDelete(one_id)
        AddOnProduct.add_on_products = Convert.convert(
          Builtins.filter(AddOnProduct.add_on_products) do |one_addon|
            Ops.get_integer(one_addon, "media", -42) != one_id
          end,
          :from => "list <map>",
          :to   => "list <map <string, any>>"
        )
      end

      nil
    end

    def remove_services
      service_files = Dir[File.join(Installation.destdir, "/etc/zypp/services.d/*.service")]

      if !service_files.empty?
        backup_dir = File.join(Installation.destdir, "var/adm/backup/upgrade/zypp/services.d")
        ::FileUtils.mkdir_p(backup_dir) unless File.exist?(backup_dir)

        log.info "Moving #{service_files} to #{backup_dir}"
        ::FileUtils.mv(service_files, backup_dir)
      end
    end

    def InsertCorrectMediaHandler(url, name)
      if !Builtins.regexpmatch(url, "^cd:/") &&
          !Builtins.regexpmatch(url, "^dvd:/")
        Builtins.y2milestone("URL is not a CD/DVD")
        return true
      end

      # true - OK, continue
      if Popup.AnyQuestion(
          _("Correct Media Requested"),
          Builtins.sformat(
            _(
              "Make sure that media with label %1\n" +
                "is in the CD/DVD drive.\n" +
                "\n" +
                "If you skip it, the repository will not be added.\n"
            ),
            name
          ),
          Label.OKButton,
          Label.SkipButton,
          :yes
        ) == true
        Pkg.SourceReleaseAll
        return true
      end

      # false - skip
      false
    end

    # Adds selected repositories as <tt>enabled</tt>
    def IUU_AddEnabledRepositories
      return if Builtins.size(@repos_to_add) == 0

      Progress.Title(_("Adding enabled repositories..."))
      Progress.NextStage

      # Adding repositories in a disabled state, then enable them
      # for the system upgrade
      Builtins.foreach(@repos_to_add) do |one_id|
        Builtins.y2milestone("Adding repository: %1", one_id)
        Progress.NextStep
        one_url = Ops.get(@id_to_url, one_id, "")
        repo_name = Ops.get(@id_to_name, one_id, "")
        pth = "/"
        if one_url == nil || one_url == ""
          Builtins.y2error("Repository id %1 has no URL", one_id)
          next
        end
        if InsertCorrectMediaHandler(one_url, repo_name) != true
          Builtins.y2warning("Skipping repository %1", one_id)
          next
        end
        repo_type = Pkg.RepositoryProbe(one_url, "/")
        Builtins.y2milestone(
          "Probed repository: %1 type: %2",
          one_url,
          repo_type
        )
        if (repo_type == nil || repo_type == "NONE") &&
            Builtins.substring(one_url, 0, 4) == "dir:"
          one_url = Ops.add("dir:/mnt", Builtins.substring(one_url, 4))
          repo_type = Pkg.RepositoryProbe(one_url, "/")
          Builtins.y2milestone(
            "Probed possible local repository again: %1 type: %2",
            one_url,
            repo_type
          )
        end
        if repo_type == nil || repo_type == "NONE"
          Builtins.y2error("Cannot probe repository %1", one_id)
          Report.Error(
            Builtins.sformat(
              _(
                "Cannot add repository %1\n" +
                  "URL: %2\n" +
                  "\n" +
                  "\n" +
                  "Repository will be added in disabled state."
              ),
              repo_name,
              one_url
            )
          )

          # see bnc#779396
          # Repository cannot be probed, it has to be added in disabled state
          @repos_to_add_disabled = Builtins.add(@repos_to_add_disabled, one_id)
          next
        end
        # see bnc #310209
        # Adding repositories with their correct names
        repoadd = {
          @REPO_ENABLED => false,
          "name"        => repo_name,
          "base_urls"   => [one_url],
          "prod_dir"    => pth,
          "type"        => repo_type,
          # bnc #543468, do not check aliases of repositories stored in Installation::destdir
          "check_alias" => false
        }
        repoadd_ref = arg_ref(repoadd)
        AdjustRepoSettings(repoadd_ref, one_id)
        repoadd = repoadd_ref.value
        Builtins.y2milestone("Adding repo (enabled): %1", repoadd)
        new_id = Pkg.RepositoryAdd(repoadd)
        if new_id == nil || new_id == -1
          Builtins.y2error("Error adding repository: %1", repoadd)
          Report.Error(
            Builtins.sformat(
              _(
                "Cannot add enabled repository\n" +
                  "Name: %1\n" +
                  "URL: %2"
              ),
              repo_name,
              one_url
            )
          )
          next
        end
        if Ops.greater_than(new_id, -1)
          repo_refresh = Pkg.SourceRefreshNow(new_id)
          Builtins.y2milestone("Repository refreshed: %1", repo_refresh)

          if repo_refresh != true
            Report.Error(
              Builtins.sformat(
                # TRANSLATORS: error report
                # %1 is replaced with repo-name, %2 with repo-URL
                _(
                  "An error occurred while refreshing repository\n" +
                    "Name: %1\n" +
                    "URL: %2"
                ),
                repo_name,
                one_url
              )
            )
            next
          end

          repo_enable = Pkg.SourceSetEnabled(new_id, true)
          Builtins.y2milestone("Repository enabled: %1", repo_enable)

          if repo_enable != true
            Report.Error(
              Builtins.sformat(
                # TRANSLATORS: error report
                # %1 is replaced with repo-name, %2 with repo-URL
                _(
                  "An error occurred while enabling repository\n" +
                    "Name: %1\n" +
                    "URL: %2\n"
                ),
                repo_name,
                one_url
              )
            )
            next
          end

          AddOnProduct.Integrate(new_id)

          prod = Convert.convert(
            Pkg.SourceProductData(new_id),
            :from => "map <string, any>",
            :to   => "map <string, string>"
          )
          Builtins.y2milestone("Product Data: %1", prod)

          AddOnProduct.add_on_products = Builtins.add(
            AddOnProduct.add_on_products,
            {
              "media"            => new_id,
              "media_url"        => one_url,
              "product_dir"      => pth,
              "product"          => repo_name,
              "autoyast_product" => repo_name
            }
          )
        end
      end

      nil
    end

    # Adds selected repositories as <tt>disabled</tt>
    def IUU_AddDisabledRepositories
      return if Builtins.size(@repos_to_add_disabled) == 0

      Progress.Title(_("Adding disabled repositories..."))
      Progress.NextStage

      # Adding the rest of repositories in a disabled state
      # bnc #326342
      Builtins.y2milestone("Adding DISABLED repos: %1", @repos_to_add_disabled)

      Builtins.foreach(@repos_to_add_disabled) do |one_id|
        Progress.NextStep
        one_url = Ops.get(@id_to_url, one_id, "")
        repo_name = Ops.get(@id_to_name, one_id, "")
        pth = "/"
        if InsertCorrectMediaHandler(one_url, repo_name) != true
          Builtins.y2warning("Skipping repository %1", one_id)
          next
        end
        # see bnc #310209
        # Adding repositories with their correct names
        repoadd = {
          @REPO_ENABLED => false,
          "name"        => repo_name,
          "base_urls"   => [one_url],
          "prod_dir"    => pth,
          # bnc #543468, do not check aliases of repositories stored in Installation::destdir
          "check_alias" => false
        }
        repoadd_ref = arg_ref(repoadd)
        AdjustRepoSettings(repoadd_ref, one_id)
        repoadd = repoadd_ref.value
        # do not probe! adding as disabled!
        repo_type = FindURLType(one_url)
        if repo_type != nil && repo_type != ""
          Ops.set(repoadd, "type", repo_type)
        end
        Builtins.y2milestone("Adding repo (disabled): %1", repoadd)
        new_id = Pkg.RepositoryAdd(repoadd)
        if new_id == nil || new_id == -1
          Builtins.y2error("Error adding repository: %1", repoadd)
          Report.Error(
            Builtins.sformat(
              _(
                "Cannot add disabled repository\n" +
                  "Name: %1\n" +
                  "URL: %2"
              ),
              repo_name,
              one_url
            )
          )
        end
      end

      nil
    end

    def SourceIsRemote(url)
      return false if Builtins.regexpmatch(url, "^cd://")
      return false if Builtins.regexpmatch(url, "^dvd://")
      return false if Builtins.regexpmatch(url, "^disk://")

      true
    end

    def FindMediaNr(_alias, url)
      if _alias == "" || _alias == nil
        Builtins.y2error("alias not defined!")
        return nil
      end

      if url == "" || url == nil
        Builtins.y2error("URL not defined!")
        return nil
      end

      ret = nil

      Builtins.foreach(@already_registered_repos) do |one_url|
        if _alias == Ops.get_string(one_url, "alias", "-A-") &&
            url == Ops.get_string(one_url, "url", "-A-")
          ret = Ops.get_integer(one_url, "media", -1)
          raise Break
        end
      end

      ret
    end

    def AddOrRemoveRepositories
      @repos_to_remove = []
      @repos_to_add = []
      @id_to_url = {}
      @repos_to_add_disabled = []
      @repo_files_to_remove = []

      # bnc #400823
      @do_not_remove = Ops.get(Pkg.SourceGetCurrent(false), 0, 0)

      some_sources_are_remote = false

      Builtins.foreach(@urls) do |one_source|
        url = Ops.get_string(one_source, "url", "")
        id = Ops.get_string(one_source, "id", "")
        some_sources_are_remote = true if SourceIsRemote(url)
        Ops.set(@id_to_url, id, url)
        # bnc #400823
        current_medianr = FindMediaNr(
          Builtins.tostring(Ops.get(one_source, "alias")),
          Builtins.tostring(Ops.get(one_source, "url"))
        )
        if @do_not_remove == current_medianr
          Builtins.y2milestone(
            "Skipping installation repository: %1",
            @do_not_remove
          )
          next
        end
        Builtins.y2milestone("Checking repo: %1", one_source)
        # Source should be enabled at the end
        if Ops.get_string(one_source, "new_status", "") == @REPO_ENABLED
          if Ops.get_string(one_source, "initial_url_status", "") == @REPO_ENABLED
            Builtins.y2milestone("Repository has been already enabled")
          else
            # It's not yet enabled, add it
            @repos_to_add = Builtins.add(@repos_to_add, id)
            Builtins.y2milestone("Repository to add: %1", id)

            # It's been already added but in disabled state
            if Ops.get_string(one_source, "initial_url_status", "") == @REPO_DISABLED
              @repos_to_remove = Builtins.add(@repos_to_remove, current_medianr)
              Builtins.y2milestone("Repository to remove: %1", current_medianr)
            end
          end

          # Repository should be removed (not added)
        elsif Ops.get_string(one_source, "new_status", "") == @REPO_REMOVED
          if Ops.get_string(one_source, "initial_url_status", "") == @REPO_REMOVED
            Builtins.y2milestone("Repository not loaded or already removed")
            # repository is not known to pkg-bindings, remove the repo file directly
            @repo_files_to_remove << one_source
          else
            @repos_to_remove = Builtins.add(@repos_to_remove, current_medianr)
            Builtins.y2milestone("Repository to remove: %1", current_medianr)
          end

          # Repositry will be added in disabled state
          # BNC #583155
        elsif Ops.get_string(one_source, "new_status", "") == @REPO_DISABLED
          # It's been already added in enabled state
          if Ops.get_string(one_source, "initial_url_status", "") == @REPO_ENABLED
            @repos_to_remove = Builtins.add(@repos_to_remove, current_medianr)
            Builtins.y2milestone("Repository to remove: %1", current_medianr)
          end

          @repos_to_add_disabled = Builtins.add(@repos_to_add_disabled, id)
          Builtins.y2milestone("Repository to add disabled: %1", id)
        end
      end

      if Ops.greater_than(Builtins.size(@repos_to_remove), 0) ||
          Ops.greater_than(Builtins.size(@repos_to_add), 0)
        SetAddRemoveSourcesUI()
      end

      # BNC #478024: Remote repositories need a running network
      if Ops.greater_than(Builtins.size(@repos_to_add), 0) && !NetworkRunning()
        Builtins.y2milestone(
          "No network is running, trying inst_network_check fallback"
        )
        ret = WFM.CallFunction("inst_network_check", [])
        Builtins.y2milestone("Called inst_network_check returned: %1", ret)
      end

      # Remote repositories without running network are registered
      # as disabled
      if Ops.greater_than(Builtins.size(@repos_to_add), 0) && !NetworkRunning()
        Builtins.y2warning(
          "Network is not running, repositories will be added in DISABLED state"
        )
        @repos_to_add_disabled = Convert.convert(
          Builtins.union(@repos_to_add_disabled, @repos_to_add),
          :from => "list",
          :to   => "list <string>"
        )
        @repos_to_add = []
      end

      @repos_to_remove = Builtins.filter(@repos_to_remove) do |one_source|
        one_source != @do_not_remove
      end

      @repos_to_add_disabled = Builtins.filter(@repos_to_add_disabled) do |one_source|
        one_source != Builtins.sformat("ID: %1", @do_not_remove)
      end

      progress = Progress.status

      Progress.set(false) if Builtins.size(@repos_to_add) == 0

      SetAddRemoveSourcesProgress()

      PackageCallbacks.RegisterEmptyProgressCallbacks

      # (re)move old services - there is no UI for services,
      # but we really need to get rid of the old NCC service...
      remove_services

      IUU_RemoveRepositories()

      # Add repositories in enabled state
      IUU_AddEnabledRepositories()

      # Add repositories in disabled state
      IUU_AddDisabledRepositories()

      Progress.Finish

      PackageCallbacks.RestorePreviousProgressCallbacks

      Progress.set(progress) if Builtins.size(@repos_to_add) == 0

      :next
    end
  end
end

Yast::InstUpgradeUrlsClient.new.main

# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
# Copyright (c) 2020 SUSE LLC
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

require "yast"
require "installation/upgrade_repo_manager"
require "y2packager/repository"

Yast.import "GetInstArgs"
Yast.import "Label"
Yast.import "Mode"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "Stage"
Yast.import "UI"
Yast.import "Wizard"

module Yast
  # This client allows reusing the old repositories during system upgrade.
  #
  # @note For testing in an installed system use this command:
  #      YAST_TEST=1 yast2 inst_upgrade_urls
  #   It will load the current repositories from the system,
  #   the changes will NOT be saved.
  class InstUpgradeUrlsClient < Client
    include Yast::Logger

    def main
      textdomain "installation"

      ret = GetInstArgs.going_back ? :back : :next

      if test?
        log.info("Test mode activated")
        init_pkg_mgr
      elsif !Stage.initial || !Mode.update
        log.info("Not in update mode or initial stage")
        return ret
      end

      # use ::Installation avoid collision with Yast::Installation
      @repo_manager = ::Installation::UpgradeRepoManager.create_from_old_repositories

      # nothing to show
      if repo_manager.repositories.empty?
        log.info("No old repository defined, skipping the dialog")
        return ret
      end

      ret = run_dialog

      log.info("Returning #{ret.inspect}")
      ret
    end

  private

    attr_reader :repo_manager

    # Run the main dialog
    #
    # @return [Symbol] the UserInput symbol
    def run_dialog
      # just for testing purposes
      Wizard.CreateDialog if Mode.normal

      display_dialog
      refresh_dialog

      ret = handle_dialog
      if ret == :next
        repo_manager.activate_changes
        save_pkg_mgr
      end

      # just for testing purposes
      Wizard.CloseDialog if Mode.normal

      ret
    end

    def display_dialog
      Wizard.SetContents(
        # TRANSLATORS: dialog caption
        _("Previously Used Repositories"),
        VBox(
          # TRANSLATORS: dialog text, possibly multiline,
          # Please, do not use more than about 50 characters per line.
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

      nil
    end

    def translated_repo_status(status)
      case status
      when :removed
        # TRANSLATORS: The repository status
        _("Removed")
      when :disabled
        # TRANSLATORS: The repository status
        _("Disabled")
      when :enabled
        # TRANSLATORS: The repository status
        _("Enabled")
      else
        # TRANSLATORS: The repository status is unknown
        _("Unknown")
      end
    end

    def refresh_dialog
      current_item = UI.QueryWidget(Id("table_of_repos"), :CurrentItem)

      items = repo_manager.repositories.map do |r|
        Item(
          Id(r.repo_alias),
          translated_repo_status(repo_manager.repo_status(r)),
          r.name,
          repo_manager.repo_url(r)
        )
      end

      UI.ChangeWidget(Id("table_of_repos"), :Items, items)

      return unless current_item
      UI.ChangeWidget(Id("table_of_repos"), :CurrentItem, current_item)
    end

    def find_repo(repo_alias)
      repo_manager.repositories.find { |r| r.repo_alias == repo_alias }
    end

    def edit_item(repo)
      url = repo_manager.repo_url(repo)
      # limit the minimal width
      min_width = [url.size, 60].max

      UI.OpenDialog(
        VBox(
          # TRANSLATORS: Text entry for changing the repositoru URL
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
      url = UI.QueryWidget(Id(:url), :Value)
      UI.CloseDialog

      return unless ret == :ok

      repo_manager.change_url(repo, url)
    end

    def handle_dialog
      log.info("Offering repositories: #{repo_manager.repositories.map(&:repo_alias).inspect}")

      ret = nil

      loop do
        ret = UI.UserInput
        ret = :abort if ret == :cancel

        case ret
        when :toggle, :edit, "table_of_repos"
          current_item = UI.QueryWidget(Id("table_of_repos"), :CurrentItem)
          next unless current_item

          selected_repo = repo_manager.repositories.find { |r| r.repo_alias == current_item }
          if !selected_repo
            log.error("Selected repository not found???")
            next
          end

          if ret == :edit
            edit_item(selected_repo)
          else
            repo_manager.toggle_repo_status(selected_repo)
          end

          refresh_dialog
        when :next, :back
          break
        when :abort
          break if Popup.ConfirmAbort(:painless)
        else
          log.warn("Unknown input: #{ret}")
        end
      end

      ret
    end

    # Initialize the package manager and read the current repositories.
    # This is only needed in the testing mode to display some reasonable values,
    # it reads the data from the current system.
    def init_pkg_mgr
      # import the pkg-bindings module
      Yast.import "Pkg"
      Yast.import "PackageCallbacks"
      # display progress during refresh
      PackageCallbacks.InitPackageCallbacks
      # initialize the target
      Pkg.TargetInitialize("/")
      # load the repository configuration. Refreshes the repositories if needed.
      Pkg.SourceRestore
      # read the current setup
      Y2Packager::OriginalRepositorySetup.instance.read
    end

    # Save the changes to disk, reset the stored old repositories to not display
    # this dialog again after going back.
    def save_pkg_mgr
      # do not save the changes in the test mode
      Pkg.SourceSaveAll unless test?

      # clear the old repositories
      Y2Packager::OriginalRepositorySetup.instance.repositories.clear
    end

    # Running in a test mode?
    #
    # @return [Boolean] `true` if running in the test mode, `false` otherwise
    def test?
      ENV["YAST_TEST"] == "1"
    end
  end
end

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

# File:	clients/inst_scenarios.ycp
# Package:	Installation (First Stage)
# Summary:	Server/Desktop Scenarios
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
module Yast
  class InstScenariosClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"
      # See FATE: #304373: Align installation process to use scenarios for Server in early stage

      textdomain "installation"

      Yast.import "Arch"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Wizard"
      Yast.import "Icon"
      Yast.import "Installation"
      Yast.import "Popup"
      Yast.import "PackageCallbacks"
      Yast.import "Report"
      Yast.import "Packages"
      Yast.import "DefaultDesktop"
      Yast.import "PackagesProposal"

      @test_mode = false

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        Builtins.y2milestone("Args: %1", WFM.Args)
        @test_mode = true if WFM.Args(0) == "test"
      end

      # load supported scenarios from control file
      @any_scenarios = ProductFeatures.GetFeature(
        "software",
        "system_scenarios"
      )

      if @any_scenarios.nil? || @any_scenarios == "" || @any_scenarios == []
        Builtins.y2error("Undefined software->system_scenarios")
        return :auto
      end

      @system_scenarios = Convert.convert(
        @any_scenarios,
        from: "any",
        to:   "list <map <string, string>>"
      )

      # Remove Xen/KVM Virtualization Host Server Installation for non-x86_64 (bnc#702103, bnc#795067)
      @system_scenarios = Builtins.filter(@system_scenarios) do |one_scenario|
        if Builtins.issubstring(
          Ops.get(one_scenario, "id", "---"),
          "virtualization_host"
          ) &&
            !Arch.x86_64
          Builtins.y2milestone("removing Xen Virtualization Host Server option")
          next false
        end
        true
      end

      @packages_proposal_ID = "inst_scenarios"

      # adjusting test mode - not used in installation
      if @test_mode
        Wizard.CreateDialog
        Pkg.TargetInit(Installation.destdir, true)
        Pkg.SourceStartManager(true)
        # pre-select
        Builtins.foreach(
          Builtins.splitstring(
            Ops.get(@system_scenarios, [0, "patterns"], ""),
            " \t"
          )
        ) { |one_pattern| Pkg.ResolvableInstall(one_pattern, :pattern) }
        Pkg.PkgSolve(true)
      end

      Builtins.y2milestone("Supported scenarios: %1", @system_scenarios)

      # TRANSLATORS: help text
      @dialog_help = _(
        "<p>Select the scenario that meets your needs best.\nAdditional software can be selected later in software proposal.</p>\n"
      )

      # Adjust dialog
      Wizard.SetContents(
        ProductControl.GetTranslatedText("scenarios_caption"),
        GetDialogContents(),
        @dialog_help,
        true,
        true
      )
      Wizard.SetTitleIcon("yast-software")

      SelectAppropriateRadioButton()

      @user_input = nil
      @ret = :auto

      # Handle user input
      loop do
        @user_input = UI.UserInput

        if @user_input == :next
          @chosen_selection = Convert.to_string(
            UI.QueryWidget(Id(:scenarios), :CurrentButton)
          )

          if @chosen_selection.nil? || @chosen_selection == ""
            # TRANSLATORS: pop-up message
            Report.Message(_("Choose one scenario, please."))
          else
            SelectPatterns(@chosen_selection)
            @ret = :next
            break
          end
        elsif @user_input == :back
          @ret = :back
          break
        elsif @user_input == :abort || @user_input == :cancel
          if Popup.ConfirmAbort(:painless)
            @ret = :abort
            break
          end
        else
          Builtins.y2error("Unexpected ret: %1", @user_input)
        end
      end

      # test mode - not used in installation
      Wizard.CloseDialog if @test_mode

      Builtins.y2milestone("Returning: %1", @ret)
      @ret
      # EOF
    end

    # Adjusts UI - selected radio button
    def SelectAppropriateRadioButton
      patterns = Pkg.ResolvableProperties("", :pattern, "")

      selected_id = nil

      # check all scenarios
      Builtins.foreach(@system_scenarios) do |one_scenario|
        patterns_required = Builtins.splitstring(
          Ops.get(one_scenario, "patterns", ""),
          " \t"
        )
        matching_patterns = 0
        Builtins.foreach(patterns) do |one_pattern|
          if Builtins.contains(
            patterns_required,
            Ops.get_string(one_pattern, "name", "")
            ) &&
              (Ops.get_symbol(one_pattern, "status", :a) == :installed ||
                Ops.get_symbol(one_pattern, "status", :a) == :selected)
            matching_patterns = Ops.add(matching_patterns, 1)
          end
        end
        # there are some matching patterns
        # they match required patterns
        if Ops.greater_than(matching_patterns, 0) &&
            Ops.greater_or_equal(
              matching_patterns,
              Builtins.size(patterns_required)
            )
          Builtins.y2milestone(
            "Matching: %1 (%2)",
            Ops.get(one_scenario, "id", ""),
            Ops.get(one_scenario, "patterns", "")
          )
          if selected_id.nil?
            selected_id = Ops.get(one_scenario, "id", "")
          else
            Builtins.y2warning("Scenario %1 already selected", selected_id)
          end
        end
      end

      # matching patterns found
      if !selected_id.nil?
        UI.ChangeWidget(Id(:scenarios), :CurrentButton, selected_id)

        # using fallback from control file
      else
        default_selection = ProductFeatures.GetStringFeature(
          "software",
          "default_system_scenario"
        )

        if default_selection.nil? || default_selection == ""
          Builtins.y2warning("No default selection defined")
        else
          Builtins.y2milestone("Pre-selecting default selection")
          if UI.WidgetExists(Id(default_selection))
            UI.ChangeWidget(Id(:scenarios), :CurrentButton, default_selection)
          else
            Builtins.y2error("No such selection: %1", default_selection)
          end
        end
      end

      nil
    end

    def SelectPatterns(chosen_selection)
      Builtins.y2milestone("User selected: %1", chosen_selection)

      # select newly selected patterns for installation
      Builtins.foreach(@system_scenarios) do |one_scenario|
        if Ops.get(one_scenario, "id", "---") == chosen_selection
          patterns_to_install = Builtins.splitstring(
            Ops.get(one_scenario, "patterns", ""),
            " \t"
          )
          # Select new list of patterns
          PackagesProposal.SetResolvables(
            @packages_proposal_ID,
            :pattern,
            patterns_to_install
          )
          raise Break
        end
      end

      # conflicts with the default desktop feature, thus it removes
      # the resolvables that the DefaultDesktop could require
      Builtins.y2warning("Removing all default_desktop related resolvables...")
      DefaultDesktop.SetDesktop(nil)

      nil
    end

    def GetDialogContents
      dialog_content = VBox()

      Builtins.foreach(@system_scenarios) do |one_scenario|
        dialog_content = Builtins.add(
          dialog_content,
          HBox(
            HWeight(
              1,
              if Ops.get(one_scenario, "icon", "") == ""
                Empty()
              else
                HBox(
                  Image(Icon.IconPath(Ops.get(one_scenario, "icon", "")), ""),
                  HSpacing(2)
                )
              end
            ),
            Left(
              RadioButton(
                Id(Ops.get(one_scenario, "id", "")),
                ProductControl.GetTranslatedText(
                  Ops.get(one_scenario, "id", "")
                )
              )
            ),
            HStretch()
          )
        )
        dialog_content = Builtins.add(dialog_content, VSpacing(0.8))
      end

      dialog_content = VBox(
        Label(ProductControl.GetTranslatedText("scenarios_text")),
        VSpacing(2),
        HSquash(
          Frame(
            # TRANSLATORS: frame label
            _("Choose Scenario"),
            RadioButtonGroup(Id(:scenarios), MarginBox(2, 1.3, dialog_content))
          )
        )
      )

      deep_copy(dialog_content)
    end
  end
end

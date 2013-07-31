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

# File:	clients/inst_automatic_configuration.ycp
# Package:	installation
# Summary:	Automatic configuration instead of the second stage
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# @see #http://visnov.blogspot.com/2008/02/getting-rid-of-2nd-stage-of.html
module Yast
  class InstAutomaticConfigurationClient < Client
    def main
      Yast.import "UI"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "FileUtils"
      Yast.import "Directory"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"
      Yast.import "Progress"
      # reads the control file
      # and sets sections of ProductFeatures
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "InstError"

      textdomain "installation"

      if GetInstArgs.going_back
        # bnc #395098
        # There is no reason to go back as AC is non-interactive
        # and additionally there is nothing before AC to run
        Builtins.y2milestone("Returning `next, no reason to go back")
        return :next
      end

      @test_mode = false

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        Builtins.y2milestone("Args: %1", WFM.Args)
        @test_mode = true if WFM.Args(0) == "test"
      end

      Wizard.CreateDialog if @test_mode

      Builtins.y2milestone("automatic_configuration started")

      @proposal_scripts_to_call = []

      @globals_features = ProductFeatures.GetSection("globals")
      @acc = Ops.get_list(@globals_features, "automatic_configuration", [])
      @acc_ignore = Ops.get_list(@globals_features, "ac_redraw_and_ignore", [])

      if @acc == nil || @acc == []
        Builtins.y2warning("No AC defined (%1), skipping...", @acc)
        return :next
      end

      @disabled_ac_items = ProductControl.GetDisabledACItems
      Builtins.foreach(@acc) do |one_step|
        new_step = {
          "unique" => Ops.get_string(one_step, "unique_id", ""),
          "label"  => Ops.get_string(one_step, "text_id", ""),
          "icon"   => Ops.get_string(one_step, "icon", "yast"),
          "type"   => Ops.get_string(one_step, "type", "scripts"),
          "items"  => Builtins.maplist(Ops.get_list(one_step, "ac_items", [])) do |one_ic_item|
            one_ic_item
          end
        }
        # filter out the wrong ones
        Ops.set(
          new_step,
          "items",
          Builtins.filter(Ops.get_list(new_step, "items", [])) do |one_item|
            if one_item == nil || one_item == ""
              Builtins.y2error(
                "Wrong item '%1' came from %2",
                one_item,
                one_step
              )
              next false
            end
            if Builtins.haskey(
                @disabled_ac_items,
                Ops.get_string(new_step, "unique", "")
              ) &&
                Builtins.contains(
                  Ops.get(
                    @disabled_ac_items,
                    Ops.get_string(new_step, "unique", ""),
                    []
                  ),
                  one_item
                )
              Builtins.y2milestone(
                "Item %1 found among disabled items",
                one_item
              )
              next false
            end
            true
          end
        )
        Ops.set(
          new_step,
          "label",
          ProductControl.GetTranslatedText(
            Ops.get_string(new_step, "label", "")
          )
        )
        if Ops.get_string(new_step, "label", "") == "" ||
            Ops.get(new_step, "label") == nil
          Builtins.y2error(
            "Unknown label text ID '%1', using fallback",
            Ops.get_string(new_step, "label", "")
          )
          Ops.set(new_step, "label", _("Creating automatic configuration..."))
        end
        @proposal_scripts_to_call = Builtins.add(
          @proposal_scripts_to_call,
          Convert.convert(new_step, :from => "map", :to => "map <string, any>")
        )
      end

      @nr_of_steps = 0

      @current_sub_step = 0
      @current_step = 0
      @current_client = ""
      @ac_redraw_and_ignore = nil

      @last_client = nil

      Builtins.foreach(@proposal_scripts_to_call) do |one_autoconf_call|
        @nr_of_steps = Ops.add(
          @nr_of_steps,
          # Proposals have two steps, scripts only one
          Ops.multiply(
            Ops.get_string(one_autoconf_call, "type", "") == "proposals" ? 2 : 1,
            Builtins.size(Ops.get_list(one_autoconf_call, "items", []))
          )
        )
      end

      SetWizardContents()

      # items per step
      @nr_of_items = 0

      Builtins.foreach(@proposal_scripts_to_call) do |one_autoconf_call|
        if Ops.get_string(one_autoconf_call, "icon", "") != ""
          Wizard.SetTitleIcon(Ops.get_string(one_autoconf_call, "icon", ""))
        else
          # generic YaST icon fallback
          Wizard.SetTitleIcon("yast")
        end
        type = Ops.get_string(one_autoconf_call, "type", "")
        @nr_of_items = Ops.multiply(
          Ops.get_string(one_autoconf_call, "type", "") == "proposals" ? 2 : 1,
          Builtins.size(Ops.get_list(one_autoconf_call, "items", []))
        )
        label = Ops.get_locale(
          one_autoconf_call,
          "label",
          _("Automatic configuration...")
        )
        Builtins.y2milestone("Steps: %1, Label: %2", @nr_of_steps, label)
        case type
          when "scripts"
            CallScripts(Ops.get_list(one_autoconf_call, "items", []))
          when "proposals"
            CallProposals(Ops.get_list(one_autoconf_call, "items", []))
          else
            Builtins.y2error("Unknown script type '%1'", type)
        end
      end

      Builtins.y2milestone("automatic_configuration finished")

      # Set to 100%
      UI.ChangeWidget(Id("one_set_progress"), :Value, @nr_of_items)
      UI.ChangeWidget(Id("autoconf_progress"), :Value, @nr_of_steps)

      Wizard.CloseDialog if @test_mode

      :auto
    end

    # Prepares the list of installation scripts to be executed.
    # This comes from control file where scripts are mentioned without the leading
    # "inst_" but they are actually named that way ("inst_something").
    #
    # @example ["aa", "inst_bb"] -> ["inst_aa", "inst_bb"]
    def NormalizeScriptNames(names)
      names = deep_copy(names)
      ret_names = []

      Builtins.foreach(names) do |one_name|
        if Builtins.regexpmatch(one_name, "^inst_")
          ret_names = Builtins.add(ret_names, one_name)
        else
          ret_names = Builtins.add(ret_names, Ops.add("inst_", one_name))
        end
      end

      deep_copy(ret_names)
    end

    # Similar to NormalizeScriptNames but it add "_proposal" instead if "inst_".
    #
    # @example ["aa", "bb_proposal"] -> ["aa_proposal", "bb_proposal"]
    def NormalizeProposalNames(names)
      names = deep_copy(names)
      ret_names = []

      Builtins.foreach(names) do |one_name|
        if Builtins.regexpmatch(one_name, "_proposal$")
          ret_names = Builtins.add(ret_names, one_name)
        else
          ret_names = Builtins.add(ret_names, Ops.add(one_name, "_proposal"))
        end
      end

      deep_copy(ret_names)
    end

    def HandleExceptions(proposal_name)
      if proposal_name == "x11_proposal" || proposal_name == "x11"
        if !UI.TextMode
          Builtins.y2milestone("Printing >don't panic<!")
          SCR.Write(
            path(".dev.tty.stderr"),
            # TRANSLATORS: this message is displayed on console when X11 configuration
            # switches from running X to console. Sometimes it looks like
            # the installation has failed.
            _(
              "\n" +
                "\n" +
                "******************************************************\n" +
                "\n" +
                " Do not panic!\n" +
                "\n" +
                " X11 Configuration must switch to console for a while\n" +
                " to detect your videocard properly...\n" +
                "\n" +
                "******************************************************\n"
            )
          )
        end
      end

      nil
    end

    def SetWizardContents
      Wizard.SetContents(
        _("Automatic Configuration"),
        VBox(
          # faster progress
          ReplacePoint(
            Id("rp_one_set_progress"),
            ProgressBar(
              Id("one_set_progress"),
              _("Preparing configuration..."),
              100,
              0
            )
          ),
          # overall-autoconf progress
          ProgressBar(
            Id("autoconf_progress"),
            _("Creating automatic configuration..."),
            @nr_of_steps,
            0
          )
        ),
        _("<p>Writing automatic configuration...</p>"),
        false,
        false
      )

      nil
    end

    def DumpACUIError
      Builtins.y2error("AC progress widgets missing")
      Builtins.y2warning(
        "---------------------- UI DUMP ----------------------"
      )
      UI.DumpWidgetTree
      Builtins.y2warning(
        "---------------------- UI DUMP ----------------------"
      )

      nil
    end

    def NextStep
      # If a Progress is missing, it's recreated and an error is reported
      @last_client = @current_client if @last_client == nil
      @ac_redraw_and_ignore = @last_client == nil ?
        false :
        Builtins.contains(@acc_ignore, @last_client)

      @current_sub_step = Ops.add(@current_sub_step, 1)
      @current_step = Ops.add(@current_step, 1)

      # BNC #483211: It might happen that some client close the dialog
      if !UI.WidgetExists(Id(:next)) && !UI.WidgetExists(Id(:back)) &&
          !UI.WidgetExists(Id(:abort))
        Builtins.y2error("There is no Wizard dialog open! Creating one...")
        Wizard.OpenNextBackStepsDialog
        DumpACUIError()
        InstError.ShowErrorPopupWithLogs(
          Builtins.sformat(
            _("An error has occurred while calling '%1' AC script."),
            @last_client
          )
        )
      end

      # BNC #483211: It might happen that some client changes the dialog
      if !UI.WidgetExists(Id("one_set_progress")) ||
          !UI.WidgetExists(Id("autoconf_progress"))
        if @ac_redraw_and_ignore == true
          Builtins.y2warning(
            "There is no Automatic Configuration dialog, adjusting the current one... (ignored)"
          )
        else
          DumpACUIError()
          Builtins.y2error(
            "There is no Automatic Configuration dialog, adjusting the current one..."
          )
          InstError.ShowErrorPopupWithLogs(
            Builtins.sformat(
              _("An error has occurred while calling '%1' AC script."),
              @last_client
            )
          )
        end

        # Redraw after showing an error
        SetWizardContents()
      end

      if UI.WidgetExists(Id("one_set_progress"))
        UI.ChangeWidget(Id("one_set_progress"), :Value, @current_sub_step)
      else
        Builtins.y2error("Widget one_set_progress doesn't exist")
      end

      if UI.WidgetExists(Id("autoconf_progress"))
        UI.ChangeWidget(Id("autoconf_progress"), :Value, @current_step)
      else
        Builtins.y2error("Widget autoconf_progress doesn't exist")
      end

      nil
    end

    def DummyFunction
      Builtins.sleep(Builtins.random(1600))

      nil
    end

    def CallScripts(scripts_to_call)
      scripts_to_call = deep_copy(scripts_to_call)
      Builtins.y2milestone("Scripts to call: %1", scripts_to_call)

      scripts_to_call = NormalizeScriptNames(scripts_to_call)

      Builtins.foreach(scripts_to_call) do |one_script|
        Builtins.y2milestone("Calling script %1", one_script)
        @current_client = one_script
        NextStep()
        progress_before = Progress.set(false)
        result = @test_mode ?
          DummyFunction() :
          WFM.CallFunction(one_script, [{ "AutomaticConfiguration" => true }])
        Progress.set(progress_before)
        Builtins.y2milestone("Script %1 returned %2", one_script, result)
        @last_client = one_script
      end

      nil
    end

    def CallProposals(proposals_to_call)
      proposals_to_call = deep_copy(proposals_to_call)
      Builtins.y2milestone("Scripts to call: %1", proposals_to_call)

      proposals_to_call = NormalizeProposalNames(proposals_to_call)

      Builtins.foreach(proposals_to_call) do |one_proposal|
        Builtins.y2milestone("Calling script %1 MakeProposal", one_proposal)
        @current_client = one_proposal
        NextStep()
        progress_before = Progress.set(false)
        HandleExceptions(one_proposal)
        result = @test_mode ?
          DummyFunction() :
          WFM.CallFunction(
            one_proposal,
            ["MakeProposal", { "AutomaticConfiguration" => true }]
          )
        Progress.set(progress_before)
        Builtins.y2milestone("Script %1 returned %2", one_proposal, result)
        @last_client = one_proposal
      end

      Builtins.foreach(proposals_to_call) do |one_proposal|
        Builtins.y2milestone("Calling script %1 Write", one_proposal)
        @current_client = one_proposal
        NextStep()
        progress_before = Progress.set(false)
        result = @test_mode ?
          DummyFunction() :
          WFM.CallFunction(
            one_proposal,
            ["Write", { "AutomaticConfiguration" => true }]
          )
        Builtins.y2milestone("Script %1 returned %2", one_proposal, result)
        @last_client = one_proposal
      end

      nil
    end
  end
end

Yast::InstAutomaticConfigurationClient.new.main

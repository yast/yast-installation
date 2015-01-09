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

# File:	clients/inst_software_selection.ycp
# Package:	Installation
# Summary:	New Desktop Selection (bnc #379157)
# Authors:	Lukas Ocilka <locilka@suse.cz>
#		Stephan Kulow <coolo@suse.de>
#
# $Id$
#
module Yast
  class InstNewDesktopClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "installation"

      Yast.import "ProductFeatures"
      Yast.import "InstData"
      Yast.import "GetInstArgs"
      Yast.import "DefaultDesktop"
      Yast.import "Wizard"
      Yast.import "Packages"
      Yast.import "Popup"
      Yast.import "Stage"
      Yast.import "Directory"
      Yast.import "ProductControl"

      # do not offer the dialog if base selection is fixed
      if ProductFeatures.GetFeature("software", "selection_type") == :fixed
        return :auto
      end

      @text_mode = Ops.get_boolean(UI.GetDisplayInfo, "TextMode", false)

      # TRANSLATORS: help text, part 1
      @help = _(
        "<p>At Linux <b>choice</b> is a top priority. <i>openSUSE</i> offers a number \n" \
          "of different desktop environments. Below you see a list of the 2 major ones \n" \
          "<b>GNOME</b> and <b>KDE</b>.</p>"
      ) +
        # TRANSLATORS: help text, part 3
        _(
          "<p>You may select alternative desktop environments (or one of minimal installation patterns)\n" \
            "that could fit your needs better using the <b>Other</b> option . Later in the software \n" \
            "selection or after installation, you can change your selection or add additional desktop \n" \
            "environments. This screen allows you to set the default.</p>"
        )

      if DefaultDesktop.Desktop == nil || DefaultDesktop.Desktop == ""
        DefaultDesktop.Init
      end

      @all_desktops = DefaultDesktop.GetAllDesktopsMap

      @packages_proposal_ID = "inst_new_desktop"

      @other_desktops = []

      # filter out those desktops with unavailable patterns
      @all_desktops = Builtins.filter(@all_desktops) do |_desktop_name, one_desktop|
        PatternsAvailable(Ops.get_list(one_desktop, "patterns", []))
      end

      @major_desktops = GetDesktops("major", true)
      @major_no_descr = GetDesktops("major", false)
      @minor_desktops = GetDesktops("minor", true)

      @current_minor_d_status = false

      @default_ui_minor = Empty()

      @default_desktop = DefaultDesktop.Desktop
      if @default_desktop != nil && @default_desktop != "" &&
          Builtins.contains(@other_desktops, @default_desktop)
        @default_ui_minor = deep_copy(@minor_desktops)
        @current_minor_d_status = true
      end

      @contents = Left(
        HBox(
          HSquash(
            VBox(
              Label(ProductControl.GetTranslatedText("desktop_dialog")),
              VWeight(3, VStretch()),
              RadioButtonGroup(
                Id("selected_desktop"),
                Opt(:hstretch),
                VBox(
                  ReplacePoint(Id("major_options"), @major_desktops),
                  ReplacePoint(Id("other_options"), @default_ui_minor)
                )
              ),
              VWeight(5, VStretch())
            )
          )
        )
      )

      # TRANSLATORS: dialog caption
      @caption = _("Desktop Selection")

      # Set UI
      Wizard.SetContents(
        @caption,
        @contents,
        @help,
        Stage.initial ? GetInstArgs.enable_back : true,
        Stage.initial ? GetInstArgs.enable_next : true
      )
      Wizard.SetTitleIcon("yast-desktop-select")

      # Adjust default values
      if !UI.WidgetExists(Id("selected_desktop"))
        Builtins.y2error(-1, "Widget selected_desktop does not exist")
      elsif @default_desktop != nil && @default_desktop != ""
        Builtins.y2milestone(
          "Already selected desktop: %1",
          DefaultDesktop.Desktop
        )
        UI.ChangeWidget(
          Id("selected_desktop"),
          :Value,
          GetDesktopRadioButtonId(DefaultDesktop.Desktop)
        )
      end

      # UI wait loop
      @ret = nil
      loop do
        @ret = UI.UserInput

        if Ops.is_string?(@ret) &&
            Builtins.regexpmatch(
              Builtins.tostring(@ret),
              "^selected_desktop_.*"
            )
          Wizard.EnableNextButton
          @currently_selected = Builtins.regexpsub(
            Builtins.tostring(@ret),
            "^selected_desktop_(.*)",
            "\\1"
          )
          if !Builtins.contains(@other_desktops, @currently_selected)
            ShowHideOther(false)
          end
        elsif @ret == :next
          @currently_selected = Convert.to_string(
            UI.QueryWidget(Id("selected_desktop"), :Value)
          )

          if @currently_selected != nil && @currently_selected != ""
            DefaultDesktop.SetDesktop(
              Builtins.regexpsub(
                Builtins.tostring(@currently_selected),
                "^selected_desktop_(.*)",
                "\\1"
              )
            )
            Packages.ForceFullRepropose

            if DefaultDesktop.Desktop != nil &&
                Builtins.haskey(@all_desktops, DefaultDesktop.Desktop)
              SelectSoftwareNow()
              break
            end
          end

          Popup.Message(
            _(
              "No desktop type was selected.\nSelect the desired desktop environment."
            )
          ) # should not happen at all, Next is disabled
          next
        elsif @ret == :abort || @ret == :cancel
          if Popup.ConfirmAbort(Stage.initial ? :painless : :incomplete)
            @ret = :abort
            break
          end
          next
        elsif @ret == :back
          break
        elsif @ret == "__other__"
          ShowHideOther(true)
          Wizard.DisableNextButton
        else
          Builtins.y2error("Input %1 not handled", @ret)
        end
      end

      Convert.to_symbol(@ret) 

      # EOF
    end

    def SelectSoftwareNow
      Packages.ForceFullRepropose

      Builtins.y2milestone("Selected desktop: %1", DefaultDesktop.Desktop)
      # Sets PackagesProposal - packages to install
      DefaultDesktop.SetDesktop(DefaultDesktop.Desktop)

      nil
    end

    def GetDesktopRadioButtonId(desktop_name)
      if desktop_name == nil || desktop_name == ""
        Builtins.y2warning("Wrong desktop name: %1", desktop_name)
        return ""
      end

      Builtins.sformat("selected_desktop_%1", desktop_name)
    end

    def GetDesktopDescriptionId(desktop_name)
      if desktop_name == nil || desktop_name == ""
        Builtins.y2warning("Wrong desktop name: %1", desktop_name)
        return ""
      end

      Builtins.sformat("desktop_description_%1", desktop_name)
    end

    # Check if given list of patterns is available for installation
    def PatternsAvailable(patterns)
      patterns = deep_copy(patterns)
      all_available = true
      Builtins.foreach(patterns) do |pattern|
        if Ops.less_than(
          Builtins.size(Pkg.ResolvableProperties(pattern, :pattern, "")),
          1
          )
          Builtins.y2warning("pattern '%1' not found", pattern)
          all_available = false
        end
      end
      all_available
    end

    def GetDesktops(desktops, show_descr)
      sort_order        = @all_desktops.keys
      sort_order.sort!{|x,y| (@all_desktops[x]["order"] || 99) <=> (@all_desktops[y]["order"] || 99) }

      if desktops == "major"
        sort_order = Builtins.filter(sort_order) do |desktop_name|
          Ops.get_integer(@all_desktops, [desktop_name, "order"], 99) == 1
        end
      elsif desktops == "minor"
        sort_order = Builtins.filter(sort_order) do |desktop_name|
          Ops.greater_than(
            Ops.get_integer(@all_desktops, [desktop_name, "order"], 99),
            1
          )
        end
        @other_desktops = deep_copy(sort_order)
      end

      ret = VBox()

      counter = -1
      last_desktop_order = -1

      Builtins.foreach(sort_order) do |desktop_name|
        counter = Ops.add(counter, 1)
        if counter != 0 && desktops == "major"
          Ops.set(ret, counter, VSpacing(1))
          counter = Ops.add(counter, 1)
        end
        desktop_order = Ops.get_integer(
          @all_desktops,
          [desktop_name, "order"],
          99
        )
        radio_opt = Opt(:notify, :boldFont)
        radio_opt = Opt(:notify) if desktops == "minor"
        Ops.set(
          ret,
          counter,
          Left(
            HBox(
              HSpacing(desktops == "major" ? 2 : 8),
              VBox(
                Left(
                  RadioButton(
                    Id(GetDesktopRadioButtonId(desktop_name)),
                    radio_opt,
                    # BNC #449818
                    ProductControl.GetTranslatedText(
                      Ops.get_string(
                        @all_desktops,
                        [desktop_name, "label_id"],
                        ""
                      )
                    )
                  )
                ),
                desktops == "major" && show_descr ?
                  ReplacePoint(
                    Id(GetDesktopDescriptionId(desktop_name)),
                    HBox(
                      HSpacing(@text_mode ? 4 : 2),
                      # BNC #449818
                      Left(
                        Label(
                          ProductControl.GetTranslatedText(
                            Ops.get_string(
                              @all_desktops,
                              [desktop_name, "description_id"],
                              ""
                            )
                          )
                        )
                      ),
                      HSpacing(1)
                    )
                  ) :
                  Empty()
              ),
              desktops == "major" ?
                Image(
                  Ops.add(
                    Ops.add(
                      Ops.add(Directory.themedir, "/current/icons/64x64/apps/"),
                      Ops.get_string(
                        @all_desktops,
                        [desktop_name, "icon"],
                        "yast"
                      )
                    ),
                    ".png"
                  )
                ) :
                Empty()
            )
          )
        )
        last_desktop_order = desktop_order
      end

      if desktops == "major"
        counter = Ops.add(counter, 1)

        if counter != 0
          Ops.set(ret, counter, VSpacing(1))
          counter = Ops.add(counter, 1)
        end

        Ops.set(
          ret,
          counter,
          Left(
            HBox(
              HSpacing(2),
              VBox(
                Left(
                  RadioButton(
                    Id("__other__"),
                    Opt(:notify, :boldFont),
                    _("Other")
                  )
                )
              )
            )
          )
        )
      end

      deep_copy(ret)
    end

    def ShowHideOther(show)
      currently_selected = Convert.to_string(
        UI.QueryWidget(Id("selected_desktop"), :Value)
      )

      if show == true && @current_minor_d_status == false
        UI.ReplaceWidget(Id("major_options"), @major_no_descr) if @text_mode
        UI.ReplaceWidget(Id("other_options"), @minor_desktops)
        @current_minor_d_status = true
      elsif show == false && @current_minor_d_status == true
        UI.ReplaceWidget(Id("major_options"), @major_desktops) if @text_mode
        UI.ReplaceWidget(Id("other_options"), Empty())
        @current_minor_d_status = false
      end

      UI.ChangeWidget(Id("selected_desktop"), :Value, currently_selected)
      UI.SetFocus(Id(currently_selected))

      nil
    end
  end
end

Yast::InstNewDesktopClient.new.main

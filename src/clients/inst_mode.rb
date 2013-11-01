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

# File:	clients/inst_system_analysis.ycp
# Package:	Installation
# Summary:	Installation mode selection, system analysis
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class InstModeClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "installation"

      Yast.import "AddOnProduct"
      Yast.import "GetInstArgs"
      Yast.import "Installation"
      Yast.import "InstData"
      Yast.import "Kernel"
      Yast.import "Linuxrc"
      Yast.import "Mode"
      Yast.import "PackageCallbacks"
      Yast.import "Packages"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "Wizard"
      Yast.import "ProductFeatures"
      Yast.import "Directory"
      Yast.import "PackagesProposal"
      Yast.import "InstError"

      Yast.include self, "packager/storage_include.rb"
      Yast.include self, "installation/misc.rb"

      InstData.start_mode = Mode.mode

      # always check whether user wants to continue
      AddOnProduct.skip_add_ons = false

      @display_info = UI.GetDisplayInfo
      @in_textmode = Ops.get_boolean(@display_info, "TextMode", false)

      Wizard.SetTitleIcon("yast-inst-mode")

      # In case of going back from Update/New Installation
      Pkg.TargetFinish if GetInstArgs.going_back

      @other_options_enabled = InstData.have_linux && InstData.offer_update

      # bugzilla #208222
      # Release disk used as the installation source
      ReleaseHDDUsedAsInstallationSource()

      if Mode.autoinst
        Builtins.y2milestone("Autoinst -> returning `auto")
        return :auto
      end

      @show_online_repositories = ProductFeatures.GetBooleanFeature(
        "globals",
        "show_online_repositories"
      )
      # if not visible, internally disabled as well
      if @show_online_repositories != true
        Installation.productsources_selected = false
      end

      Wizard.SetContents(
        # dialog caption
        _("Installation Mode"),
        InstModeDialogContent(:install),
        InstModeDialogHelp(),
        true,
        true
      )
      Wizard.SetTitleIcon("yast-software")

      @ret = nil
      @new_mode = Mode.update ? :update : :install

      @umount_result = Linuxrc.InstallInf("umount_result")
      @media = Linuxrc.InstallInf("InstMode")
      Builtins.y2milestone(
        "Umount result: %1, inst mode: %2",
        @umount_result,
        @media
      )

      # only installation (and addon products) enabled
      if @other_options_enabled != true
        UI.ChangeWidget(Id(:update), :Enabled, false)

        # disable also icons related to options if supported by UI
        Builtins.foreach([:update]) do |image_id|
          icon_id = GenerateIconID(image_id)
          if UI.WidgetExists(Id(icon_id))
            UI.ChangeWidget(Id(icon_id), :Enabled, false)
          end
        end if !@in_textmode
      end

      Builtins.y2milestone("Initial Mode: #{Mode.mode}")
      AdjustStepsAccordingToInstallationSettings()
      begin
        @ret = Convert.to_symbol(UI.UserInput)
        Builtins.y2milestone("ret: %1", @ret)

        # Use-Add-On-Product status changed
        if @ret == :add_on
          if UI.WidgetExists(Id(:add_on))
            Installation.add_on_selected = Convert.to_boolean(
              UI.QueryWidget(Id(:add_on), :Value)
            )
            Builtins.y2milestone(
              "add_on_selected: %1",
              Installation.add_on_selected
            )
            AdjustStepsAccordingToInstallationSettings()
          end
          @ret = nil
          next
        # Use-Community-Repositories status changed
        elsif @ret == :productsources
          if UI.WidgetExists(Id(:productsources))
            Installation.productsources_selected = Convert.to_boolean(
              UI.QueryWidget(Id(:productsources), :Value)
            )
            Builtins.y2milestone(
              "productsources_selected: %1",
              Installation.productsources_selected
            )
            AdjustStepsAccordingToInstallationSettings()
          end
          @ret = nil
          next
        # Adjusting current UI - Hide Other Options
        # in case of `install, `update, or `repair clicked
        elsif Builtins.contains([:install, :update], @ret)
          @selected_mode = Convert.to_symbol(
            UI.QueryWidget(Id(:inst_mode), :CurrentButton)
          )

          # [(any) `check_box_id, (boolean) selected, (boolean) enabled]
          Builtins.foreach(
            [
              [:add_on, Installation.add_on_selected, @ret != :repair],
              [
                :productsources,
                Installation.productsources_selected,
                @show_online_repositories && @ret != :repair
              ]
            ]
          ) do |one_item|
            if UI.WidgetExists(Id(one_item.first))
              UI.ChangeWidget(Id(one_item.first), :Enabled, one_item[2])
              UI.ChangeWidget(Id(one_item.first), :Value, one_item[1])
            end
          end

          # Switch the mode and steps ASAP
          if @selected_mode == :install
            Mode.SetMode("installation")
          elsif @selected_mode == :update
            Mode.SetMode("update")
          end

          Builtins.y2milestone("New mode has been selected: %1", Mode.mode)
          AdjustStepsAccordingToInstallationSettings()

          next 

          # Next button
        elsif @ret == :next
          @new_mode = Convert.to_symbol(
            UI.QueryWidget(Id(:inst_mode), :CurrentButton)
          )
          if @new_mode == nil
            # this is a label of a message box
            Popup.Message(_("Choose one of the\noptions to continue."))
            @ret = nil
            next
          end

          next 

          # Abort button
        elsif @ret == :abort
          if Popup.ConfirmAbort(Stage.initial ? :painless : :incomplete)
            return :abort
          end
          @ret = nil
          next
        end
      end until @ret == :back || @ret == :next

      # <-- Handling User Input in Installation Mode

      Builtins.y2milestone("Selected mode: %1, Return: %2", @new_mode, @ret)

      if @ret == :next
        Builtins.y2milestone(
          "Disabled modules: %1",
          ProductControl.GetDisabledModules
        )
      elsif @ret == :back || @ret == :finish
        Builtins.y2milestone("Returning: %1", @ret)
        return @ret
      end

      # bugzilla #293808
      # Check (and setup) the network only when needed
      if @new_mode != :repair &&
          (Installation.add_on_selected || Installation.productsources_selected)
        # Check and setup network
        @inc_ret = Convert.to_symbol(WFM.CallFunction("inst_network_check", []))
        Builtins.y2milestone("inst_network_check ret: %1", @inc_ret)
        return @inc_ret if Builtins.contains([:back, :abort], @inc_ret)
      end

      # bug #302384
      Wizard.SetContents(
        _("Initializing"),
        # TRANSLATORS: progress message
        Label(_("Initializing...")),
        "",
        false,
        false
      )
      Wizard.SetTitleIcon("yast-software")

      if Mode.mode != InstData.start_mode
        Builtins.y2milestone(
          "Switching Steps from %1 to %2 ",
          InstData.start_mode,
          Mode.mode
        )
        UpdateWizardSteps()
        Builtins.y2milestone("Resetting disk target to read values")
        Storage.ResetOndiskTarget
        Builtins.y2debug(
          "Original target map (from disk): %1",
          Storage.GetTargetMap
        )
        Builtins.y2milestone("Resetting package manager")
        Kernel.ProbeKernel
        Pkg.TargetFinish
        Pkg.PkgReset
        # Resets all resolvables required by installation/update parts
        # Particular modules will add them again when needed
        PackagesProposal.ResetAll
        Packages.Init(true)
        SetRequiredPackages()

        @ret = ProductControl.RunFrom(
          Ops.add(ProductControl.CurrentStep, 1),
          false
        )

        @ret = :finish if @ret == :next
      else
        UpdateWizardSteps()
        SetRequiredPackages()
        @ret = ProductControl.RunFrom(
          Ops.add(ProductControl.CurrentStep, 1),
          false
        )

        @ret = :finish if @ret == :next
      end

      @ret 

      # EOF
    end

    def GenerateIconID(icon_whatever)
      icon_whatever = deep_copy(icon_whatever)
      Builtins.sformat("icon_%1", Builtins.tostring(icon_whatever))
    end

    # Function creates term containing radio button and icon
    # based on current display (graphical/textual)
    #
    # @param string radio button label
    # @param symbol radio button id
    # @param string path to an image
    # @boolean whether selected (more than one buttons selected don't make sense!)
    def CreateRadioButtonTerm(button_label, button_id, icon_file, selected)
      HBox(
        @in_textmode ?
          Empty() :
          HWeight(
            1,
            icon_file == "" ?
              Empty() :
              Image(Id(GenerateIconID(button_id)), icon_file, "")
          ),
        HWeight(
          5,
          Left(RadioButton(Id(button_id), Opt(:notify), button_label, selected))
        )
      )
    end

    # see bugzilla #156529
    def InstModeDialogContent(pre_selected)
      HBox(
        HStretch(),
        VBox(
          Frame(
            # frame
            _("Select Mode"),
            VBox(
              # Basis RadioButtonGroup
              RadioButtonGroup(
                Id(:inst_mode),
                MarginBox(
                  2,
                  1.3,
                  VBox(
                    # radio button
                    CreateRadioButtonTerm(
                      _("New &Installation"),
                      :install,
                      Ops.add(
                        Directory.themedir,
                        "/current/icons/48x48/apps/yast-dirinstall.png"
                      ),
                      !Mode.update
                    ),
                    VSpacing(0.3),
                    CreateRadioButtonTerm(
                      # radio button
                      _("&Update an Existing System"),
                      :update,
                      Ops.add(
                        Directory.themedir,
                        "/current/icons/48x48/apps/yast-update.png"
                      ),
                      Mode.update
                    )
                  )
                )
              )
            )
          ),
          VSpacing(2),
          @show_online_repositories == true ?
            Left(
              CheckBox(
                Id(:productsources),
                Opt(:notify),
                # check box
                _("&Add Online Repositories Before Installation"),
                Installation.productsources_selected
              )
            ) :
            Empty(),
          Left(
            CheckBox(
              Id(:add_on),
              Opt(:notify),
              # check box
              _("In&clude Add-on Products from Separate Media"),
              Installation.add_on_selected
            )
          )
        ),
        HStretch()
      )
    end

    def InstModeDialogHelp
      # help text for installation method
      _("<p><big><b>Installation Mode</b></big><br>\nSelect what to do:</p>") +
        # help text for installation method
        _(
          "<p>\n" +
            "Select <b>New Installation</b> if there is no existing Linux system on your\n" +
            "machine or if you want to replace an existing Linux system completely,\n" +
            "discarding all its configuration data.\n" +
            "</p>\n"
        ) +
        # help text for installation method
        _(
          "<p>\n" +
            "Select <b>Update an Existing System</b> to update a Linux system already\n" +
            "installed on your machine. This option preserves configuration settings\n" +
            "from your existing system whenever possible.\n" +
            "</p>"
        ) +
        # help text for installation option
        (@show_online_repositories == true ?
          _(
            "<p>\n" +
              "To use suggested remote repositories during installation or update, select\n" +
              "<b>Add Online Repositories Before Installation</b>.</p>"
          ) :
          "") +
        # help text for installation method
        _(
          "<p>\n" +
            "To install an add-on product from separate media together with &product;, select\n" +
            "<b>Include Add-on Products from Separate Media</b>.</p>\n"
        ) +
        # help text for installation method
        _(
          "<p>The feature <b>Update</b> is only\n" +
            "available if an existing Linux system has been detected.\n" +
            "</p>\n"
        ) +
        # help text: additional help for installation
        _(
          "<p>If you need specific hardware drivers for installation, see <i>http://drivers.suse.com</i> site.</p>"
        )
    end

    def SetRequiredPackages
      if @new_mode == :install
        Builtins.y2milestone(
          "Adding packages required for installation to succeed..."
        )
        PackagesProposal.AddResolvables(
          "YaST-Installation",
          :package,
          ["perl-Bootloader-YAML"]
        )
      end

      nil
    end
  end
end

Yast::InstModeClient.new.main

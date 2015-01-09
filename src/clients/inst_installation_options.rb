# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2014 Novell, Inc. All Rights Reserved.
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

# File:	clients/inst_installation_options.rb
# Package:	Installation
# Summary:	Initialize installation, set installation options
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
#
#
module Yast
  class InstModeClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "AddOnProduct"
      Yast.import "Installation"
      Yast.import "InstData"
      Yast.import "Linuxrc"
      Yast.import "Mode"
      Yast.import "PackageCallbacks"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "Stage"
      Yast.import "Wizard"
      Yast.import "ProductFeatures"
      Yast.import "PackagesProposal"

      Yast.include self, "packager/storage_include.rb"
      Yast.include self, "installation/misc.rb"

      InstData.start_mode = Mode.mode

      # always check whether user wants to continue
      AddOnProduct.skip_add_ons = false

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

      # nothing to display, simply continue
      if !@show_online_repositories
        SetRequiredPackages()
        return :auto
      end

      Wizard.SetContents(
        # dialog caption
        _("Installation Options"),
        InstOptionsDialogContent(),
        InstOptionsDialogHelp(),
        true,
        true
      )
      Wizard.SetTitleIcon("yast-software")

      Builtins.y2milestone(
        "Umount result: %1, inst mode: %2",
        Linuxrc.InstallInf("umount_result"),
        Linuxrc.InstallInf("InstMode")
      )

      AdjustStepsAccordingToInstallationSettings()

      loop do
        @ret = UI.UserInput
        Builtins.y2milestone("ret: %1", @ret)

        # Use-Add-On-Product status changed
        if @ret == :add_on
          if UI.WidgetExists(Id(:add_on))
            Installation.add_on_selected = UI.QueryWidget(Id(:add_on), :Value)
            Builtins.y2milestone("add_on_selected: %1", Installation.add_on_selected)
            AdjustStepsAccordingToInstallationSettings()
          end
        # Use-Community-Repositories status changed
        elsif @ret == :productsources
          if UI.WidgetExists(Id(:productsources))
            Installation.productsources_selected = UI.QueryWidget(Id(:productsources), :Value)
            Builtins.y2milestone(
              "productsources_selected: %1",
              Installation.productsources_selected
            )
            AdjustStepsAccordingToInstallationSettings()
          end
        # Abort button
        elsif @ret == :abort
          if Popup.ConfirmAbort(Stage.initial ? :painless : :incomplete)
            return :abort
          end
        end
        break if [:back, :next].include?(@ret)
      end

      # <-- Handling User Input in Installation Mode

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
      if Installation.add_on_selected || Installation.productsources_selected
        # Check and setup network
        @inc_ret = Convert.to_symbol(WFM.CallFunction("inst_network_check", []))
        Builtins.y2milestone("inst_network_check ret: %1", @inc_ret)
        return @inc_ret if [:back, :abort].include?(@inc_ret)
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

      UpdateWizardSteps()
      SetRequiredPackages()
      @ret = ProductControl.RunFrom(ProductControl.CurrentStep + 1, false)

      @ret = :finish if @ret == :next

      @ret
    end

    # see bugzilla #156529
    def InstOptionsDialogContent()
      HBox(
        HStretch(),
        VBox(
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

    def InstOptionsDialogHelp
      # help text for installation method
      _("<p><big><b>Installation Options</b></big></p>") +
        # help text for installation option
        (@show_online_repositories == true ?
          _("<p>\nTo use suggested remote repositories during installation or update, select\n" +
            "<b>Add Online Repositories Before Installation</b>.</p>") :
          "") +
        # help text for installation method
        _("<p>\nTo install an add-on product from separate media together with &product;, select\n" +
            "<b>Include Add-on Products from Separate Media</b>.</p>\n") +
        # help text: additional help for installation
        _("<p>If you need specific hardware drivers for installation, see <i>http://drivers.suse.com</i> site.</p>")
    end

    def SetRequiredPackages
      Builtins.y2milestone(
        "Adding packages required for installation to succeed..."
      )
      PackagesProposal.AddResolvables(
        "YaST-Installation",
        :package,
        ["perl-Bootloader-YAML"]
      )
    end
  end
end

Yast::InstModeClient.new.main

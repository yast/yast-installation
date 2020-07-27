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

# File: deploy_image_auto.ycp
# Module: Installation, FATE #301321: autoyast imaging
# Summary: Image deployment for AutoYaST
# Authors: Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
module Yast
  class DeployImageAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "installation"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Progress"
      Yast.import "Installation"
      Yast.import "ImageInstallation"
      Yast.import "Popup"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Starting deploy_image_auto")

      @progress_orig = Progress.set(false)

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Import"
        if Builtins.haskey(@param, "image_installation")
          ImageInstallation.changed_by_user = true
          Installation.image_installation = Ops.get_boolean(
            @param,
            "image_installation",
            false
          )
          Builtins.y2milestone(
            "Using image_installation: %1",
            Installation.image_installation
          )
          @ret = true
        else
          @ret = false
        end
      # Create a summary
      # return string
      elsif @func == "Summary"
        @ret = "<ul><li>" +
          (if Installation.image_installation
             _("Installation from images is: <b>enabled</b>")
           else
             _("Installation from images is: <b>disabled</b>")
           end) + "</li></ul>"
      # did configuration changed
      # return boolean
      elsif @func == "GetModified"
        @ret = self.class.modified
      # set configuration as changed
      # return boolean
      elsif @func == "SetModified"
        self.class.modified = true
        @ret = true
      # Reset configuration
      # return map or list
      elsif @func == "Reset"
        ImageInstallation.FreeInternalVariables
        Installation.image_installation = false
      # Change configuration
      # return symbol (i.e. `finish || `accept || `next || `cancel || `abort)
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetContentsButtons(
          # TRANSLATORS: dialog caption
          _("Installation from Images"),
          HBox(
            HStretch(),
            VBox(
              Frame(
                _("Installation from Images"),
                VBox(
                  Label(
                    _(
                      "Here you can choose to use pre-defined images to speed up RPM installation."
                    )
                  ),
                  RadioButtonGroup(
                    Id(:images_rbg),
                    MarginBox(
                      2,
                      1,
                      VBox(
                        Left(
                          RadioButton(
                            Id(:inst_from_images),
                            Opt(:notify),
                            _("&Install from Images"),
                            Installation.image_installation == true
                          )
                        ),
                        VSpacing(0.5),
                        Left(
                          RadioButton(
                            Id(:dont_inst_from_images),
                            Opt(:notify),
                            _("&Do not Install from Images"),
                            Installation.image_installation != true
                          )
                        )
                      )
                    )
                  )
                )
              )
            ),
            HStretch()
          ),
          # TRANSLATORS: help text
          _(
            "<p><b>Installation from Images</b> is used to speed the installation up.\n" \
              "Images contain compressed snapshots of an installed system matching your\n" \
              "selection of patterns. The rest of the packages which are not contained in the\n" \
              "images will be installed from packages the standard way.</p>\n"
          ),
          Label.BackButton,
          Label.OKButton
        )
        Wizard.SetAbortButton(:abort, Label.CancelButton)
        Wizard.DisableBackButton
        @selected = UI.QueryWidget(:images_rbg, :CurrentButton)
        loop do
          @ret = UI.UserInput
          Builtins.y2milestone("ret=%1", @ret)

          if @ret == :ok || @ret == :next
            @selected2 = UI.QueryWidget(:images_rbg, :CurrentButton)
            if @selected2 == :inst_from_images
              Installation.image_installation = true
            elsif @selected2 == :dont_inst_from_images
              Installation.image_installation = false
            end
            Builtins.y2milestone(
              "Changed by user, Installation from images will be used: %1",
              Installation.image_installation
            )
          end
          break if [:ok, :next, :abort].include?(@ret)
        end

        Wizard.CloseDialog
        return deep_copy(@ret)
      # Return configuration data
      # return map or list
      elsif @func == "Export"
        @ret = if Installation.image_installation
          { "image_installation" => true }
        else
          {}
        end
      # Write the configuration (prepare images, deploy images)
      elsif @func == "Write"
        Builtins.y2milestone(
          "Using images: %1",
          Installation.image_installation
        )

        # BNC #442691
        # Calling image_installation only if set to do so...
        if Installation.image_installation == true
          WFM.call("inst_prepare_image")
        end

        @ret = true
      # Read configuration data
      # return boolean
      elsif @func == "Read"
        Builtins.y2milestone("Read not supported")
        @ret = true
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end
      Progress.set(@progress_orig)

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("deploy_image_auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end

    class << self
      attr_accessor :modified
    end
  end
end

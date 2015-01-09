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
      Yast.import "AutoinstSoftware"
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
          Installation.image_installation = true
          Builtins.y2warning(
            "Key image_installation not defined, using image_installation: %1",
            Installation.image_installation
          )
        end
      # Create a summary
      # return string
      elsif @func == "Summary"
        @ret = "<ul><li>" +
          (Installation.image_installation == true ?
            _("Installation from images is: <b>enabled</b>") :
            _("Installation from images is: <b>disabled</b>")) + "</li></ul>"
      # did configuration changed
      # return boolean
      elsif @func == "GetModified"
        @ret = true
      # set configuration as changed
      # return boolean
      elsif @func == "SetModified"
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
                      "Here you can choose to use Novell pre-defined images to speed up RPM installation."
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
              ),
              VSpacing(0.5),
              Frame(
                _(
                  "Custom images deployment - this needs a URL to be configured as installation source"
                ),
                # Image name, Image location
                MarginBox(
                  2,
                  1,
                  VBox(
                    Label(
                      _("Here you can create custom images.\n") +
                        _(
                          "You have to configure the software selection first before you can create an image here"
                        )
                    ),
                    RadioButtonGroup(
                      Id(:own_images_rbg),
                      MarginBox(
                        2,
                        1,
                        VBox(
                          Frame(
                            _(
                              "Create an image file (AutoYaST will fetch it from the given location during installation)"
                            ),
                            VBox(
                              RadioButton(
                                Id(:create_image),
                                Opt(:notify, :default, :hstretch),
                                _("Create Image")
                              ),
                              TextEntry(
                                Id(:image_location),
                                Opt(:notify),
                                _(
                                  "Where will AutoYaST find the image? (e.g. http://host/)"
                                ),
                                Ops.get_string(
                                  AutoinstSoftware.image,
                                  "image_location",
                                  ""
                                )
                              ),
                              TextEntry(
                                Id(:image_name),
                                Opt(:notify),
                                _(
                                  "What is the name of the image? (e.g. my_image)"
                                ),
                                Ops.get_string(
                                  AutoinstSoftware.image,
                                  "image_name",
                                  ""
                                )
                              ),
                              VSpacing(0.5),
                              RadioButton(
                                Id(:create_iso),
                                Opt(:notify, :default, :hstretch),
                                _(
                                  "Create ISO (image and autoinst.xml will be on the media)"
                                )
                              )
                            )
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
            "<p><b>Installation from Images</b> is used to speed the installation up.\n" +
              "Images contain compressed snapshots of an installed system matching your\n" +
              "selection of patterns. The rest of the packages which are not contained in the\n" +
              "images will be installed from packages the standard way.</p>\n"
          ) +
            _(
              "<p><b>Creating own Images</b> is used if you\n" +
                "want to skip the complete step of RPM installation. Instead AutoYaST will dump an\n" +
                "image on the harddisk which is a lot faster and can be pre-configured already.\n" +
                "Everything else than RPM installation is done like during a normal auto-installation.</p>"
            ),
          Label.BackButton,
          Label.OKButton
        )
        Wizard.SetAbortButton(:abort, Label.CancelButton)
        Wizard.DisableBackButton
        @selected = UI.QueryWidget(:images_rbg, :CurrentButton)
        UI.ChangeWidget(
          Id(:create_image),
          :Enabled,
          @selected == :dont_inst_from_images
        )
        UI.ChangeWidget(
          Id(:create_iso),
          :Enabled,
          @selected == :dont_inst_from_images
        )
        UI.ChangeWidget(
          Id(:image_location),
          :Enabled,
          @selected == :dont_inst_from_images
        )
        UI.ChangeWidget(
          Id(:image_name),
          :Enabled,
          @selected == :dont_inst_from_images
        )
        loop do
          if Ops.greater_than(
              Builtins.size(
                Convert.to_string(UI.QueryWidget(:image_location, :Value))
              ),
              0
            ) ||
              Ops.greater_than(
                Builtins.size(
                  Convert.to_string(UI.QueryWidget(:image_name, :Value))
                ),
                0
              )
            UI.ChangeWidget(Id(:inst_from_images), :Enabled, false)
          else
            UI.ChangeWidget(Id(:inst_from_images), :Enabled, true)
          end

          if AutoinstSoftware.instsource == ""
            UI.ChangeWidget(Id(:create_image), :Enabled, false)
            UI.ChangeWidget(Id(:create_iso), :Enabled, false)
          end

          @ret = UI.UserInput
          Builtins.y2milestone("ret=%1", @ret)

          if @ret == :ok || @ret == :next
            @selected2 = UI.QueryWidget(:images_rbg, :CurrentButton)
            @image_type = UI.QueryWidget(:own_images_rbg, :CurrentButton)
            Ops.set(AutoinstSoftware.image, "run_kickoff", true)
            if @selected2 == :inst_from_images
              Installation.image_installation = true
              AutoinstSoftware.image = {}
            elsif @selected2 == :dont_inst_from_images
              Installation.image_installation = false
              if @image_type == :create_image
                Ops.set(
                  AutoinstSoftware.image,
                  "image_location",
                  Convert.to_string(UI.QueryWidget(:image_location, :Value))
                )
                Ops.set(
                  AutoinstSoftware.image,
                  "image_name",
                  Convert.to_string(UI.QueryWidget(:image_name, :Value))
                )
                AutoinstSoftware.createImage("")
              elsif @image_type == :create_iso
                AutoinstSoftware.createISO
              end
            end
            Builtins.y2milestone(
              "Changed by user, Installation from images will be used: %1",
              Installation.image_installation
            )
          elsif @ret == :create_image
            UI.ChangeWidget(Id(:image_location), :Enabled, true)
            UI.ChangeWidget(Id(:image_name), :Enabled, true)
            if Ops.greater_than(Builtins.size(AutoinstSoftware.patterns), 0)
              Ops.set(
                AutoinstSoftware.image,
                "image_location",
                Convert.to_string(UI.QueryWidget(:image_location, :Value))
              )
              Ops.set(
                AutoinstSoftware.image,
                "image_name",
                Convert.to_string(UI.QueryWidget(:image_name, :Value))
              )
            else
              Popup.Warning(
                _(
                  "you need to do the software selection before creating an image"
                )
              )
            end
          elsif @ret == :create_iso
            UI.ChangeWidget(Id(:image_location), :Enabled, false)
            UI.ChangeWidget(Id(:image_name), :Enabled, false)
            Ops.set(AutoinstSoftware.image, "image_name", "image")
            if Ops.less_or_equal(Builtins.size(AutoinstSoftware.patterns), 0)
              Popup.Warning(
                _(
                  "you need to do the software selection before creating an image"
                )
              )
            end
          elsif @ret == :inst_from_images || @ret == :dont_inst_from_images
            @selected2 = UI.QueryWidget(:images_rbg, :CurrentButton)
            UI.ChangeWidget(
              Id(:create_image),
              :Enabled,
              @selected2 == :dont_inst_from_images
            )
            UI.ChangeWidget(
              Id(:create_iso),
              :Enabled,
              @selected2 == :dont_inst_from_images
            )
            UI.ChangeWidget(
              Id(:image_location),
              :Enabled,
              @selected2 == :dont_inst_from_images
            )
            UI.ChangeWidget(
              Id(:image_name),
              :Enabled,
              @selected2 == :dont_inst_from_images
            )
            if @ret == :inst_from_images
              UI.ChangeWidget(Id(:create_image), :Value, false)
              UI.ChangeWidget(Id(:create_iso), :Value, false)
            end
          end
          break if [:ok, :next, :abort].include?(@ret)
        end

        Wizard.CloseDialog
        return deep_copy(@ret)
      # Return configuration data
      # return map or list
      elsif @func == "Export"
        @ret = { "image_installation" => Installation.image_installation }
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

          # moved to control.xml
          #	WFM::call ("inst_deploy_image");
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
  end
end

Yast::DeployImageAutoClient.new.main

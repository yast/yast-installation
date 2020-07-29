# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "installation/auto_client"

Yast.import "UI"
Yast.import "Label"
Yast.import "Wizard"
Yast.import "Progress"
Yast.import "Installation"
Yast.import "ImageInstallation"

module Yast
  class DeployImageAutoClient < ::Installation::AutoClient
    include Yast::Logger

    def initialize
      textdomain "installation"
    end

    def run
      progress_orig = Yast::Progress.set(false)
      ret = super
      Yast::Progress.set(progress_orig)

      ret
    end

    def import(data)
      ret = false
      if data.key?("image_installation")
        ImageInstallation.changed_by_user = true
        Installation.image_installation = data["image_installation"]
        log.info("Using image_installation: #{Installation.image_installation}")
        ret = true
      end
      ret
    end

    def summary
      ret = "<ul><li>" +
        (if Installation.image_installation
           _("Installation from images is: <b>enabled</b>")
         else
           _("Installation from images is: <b>disabled</b>")
         end) + "</li></ul>"
      ret
    end

    def modified?
      self.class.modified
    end

    def modified
      self.class.modified = true
      true
    end

    def reset
      ImageInstallation.FreeInternalVariables
      Installation.image_installation = false
      true
    end

    def change
      # Change configuration
      # return symbol (i.e. `finish || `accept || `next || `cancel || `abort)
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
      ret = :ok
      loop do
        ret = UI.UserInput
        log.info("ret={ret}")

        if ret == :ok || ret == :next
          selected = UI.QueryWidget(:images_rbg, :CurrentButton)
          if selected == :inst_from_images
            Installation.image_installation = true
          elsif selected == :dont_inst_from_images
            Installation.image_installation = false
          end
          log.info("Changed by user, Installation from images will be used: " \
            "#{Installation.image_installation}")
        end
        break if [:ok, :next, :abort].include?(ret)
      end

      Wizard.CloseDialog
      ret
    end

    def packages
      {}
    end

    def export
      if Installation.image_installation
        { "image_installation" => true }
      else
        {}
      end
    end

    def write
      log.info("Using images: #{Installation.image_installation}")
      # BNC #442691
      # Calling image_installation only if set to do so...
      WFM.call("inst_prepare_image") if Installation.image_installation

      true
    end

    def read
      log.info("Read not supported")
      true
    end

    class << self
      attr_accessor :modified
    end
  end
end

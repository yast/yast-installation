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

# Module:	deploying_proposal.ycp
#
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Purpose:	Proposal function dispatcher - deploying images
#
#		See also file proposal-API.txt for details.
# $Id$
module Yast
  class DeployingProposalClient < Client
    def main
      textdomain "installation"

      Yast.import "Mode"
      Yast.import "ImageInstallation"
      Yast.import "Progress"
      Yast.import "Installation"
      Yast.import "Report"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      @im_do_enable = "deploying_enable"
      @im_do_disable = "deploying_disable"

      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        @language_changed = Ops.get_boolean(@param, "language_changed", false)

        if @force_reset
          ImageInstallation.last_patterns_selected = [nil]
          ImageInstallation.changed_by_user = false
        end

        if ImageInstallation.changed_by_user == true &&
            Installation.image_installation == false
          Builtins.y2milestone("ImageInstallation already disabled by user")
        else
          CallProposalScript()
        end

        if Mode.installation
          @ret = {
            "preformatted_proposal" => GenerateProposalText(),
            "links"                 => [@im_do_enable, @im_do_disable],
            # TRANSLATORS: help text
            "help"                  => _(
              "<p><b>Installation from Images</b> is used to speed the installation up.\n" \
                "Images contain compressed snapshots of an installed system matching your\n" \
                "selection of patterns. The rest of the packages which are not contained in the\n" \
                "images will be installed from packages the standard way.</p>\n"
            ) +
              # TRANSLATORS: help text
              _(
                "<p>Note that when installing from images, the time stamps of all packages originating from the images will\nnot match the installation date but rather the date the image was created.</p>"
              ) +
              # TRANSLATORS: help text
              _(
                "<p>Installation from images is disabled by default if the current\npattern selection does not fit any set of images.</p>"
              )
          }
        else
          Builtins.y2error(
            "Installation from images should be used for new installation only!"
          )
          @ret = {
            "preformatted_proposal" => Builtins.sformat(
              _("Error: Images should not be used for mode: %1."),
              Mode.mode
            ),
            "warning_level"         => :error
          }
        end
      elsif @func == "AskUser"
        @chosen_id = Ops.get(@param, "chosen_id")
        Builtins.y2milestone(
          "Images proposal change requested, id %1",
          @chosen_id
        )

        @old_status = Installation.image_installation

        Installation.image_installation = if @chosen_id == @im_do_disable
          false
        elsif @chosen_id == @im_do_enable
          true
        else
          !Installation.image_installation
        end

        # changed to true
        CallProposalScript() if Installation.image_installation

        if @old_status == false &&
            @old_status == Installation.image_installation
          Report.Message(
            _(
              "Cannot enable installation from images.\n" \
                "\n" \
                "Currently selected patterns do not fit the images\n" \
                "stored on the installation media.\n"
            )
          )
        end

        ImageInstallation.changed_by_user = true
        @ret = { "workflow_sequence" => :next }
      elsif @func == "Description"
        @ret = {
          # this is a heading
          "rich_text_title" => _("Installation from Images"),
          # this is a menu entry
          "menu_title"      => _(
            "Installation from &Images"
          ),
          "id"              => "deploying"
        }
      end

      deep_copy(@ret)
    end

    def GenerateProposalText
      im_conf = ImageInstallation.ImagesToUse

      ret = "<ul>\n"

      if ImageInstallation.image_installation_available == false
        # TRANSLATORS: Installation overview
        ret = Ops.add(
          Ops.add(
            Ops.add(ret, "<li>"),
            _("No installation images are available")
          ),
          "</li>"
        )
      elsif Ops.get_boolean(im_conf, "deploying_enabled", false) == true
        ret = Ops.add(
          Ops.add(
            Ops.add(ret, "<li>"),
            Builtins.sformat(
              # TRANSLATORS: Installation overview
              # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
              _(
                "Installation from images is enabled (<a href=\"%1\">disable</a>)."
              ),
              @im_do_disable
            )
          ),
          "</li>"
        )
      else
        ret = Ops.add(
          Ops.add(
            Ops.add(ret, "<li>"),
            Builtins.sformat(
              # TRANSLATORS: Installation overview
              # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
              _(
                "Installation from images is disabled (<a href=\"%1\">enable</a>)."
              ),
              @im_do_enable
            )
          ),
          "</li>"
        )
      end

      ret = Ops.add(ret, "</ul>\n")

      ret
    end

    def CallProposalScript
      progress_orig = Progress.set(false)
      WFM.CallFunction("inst_prepare_image", [])
      Progress.set(progress_orig)

      nil
    end
  end
end

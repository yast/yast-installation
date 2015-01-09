# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2013 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------
#
# Summary: Ask for disk to deploy image to
#

module Yast
  # Asks for disk to deploy an image to.
  # Useful for OEM image installation (replacing contents of the full disk),
  # not for regular installation process
  class InstDiskForImageClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Popup"
      Yast.import "GetInstArgs"
      Yast.import "Wizard"
      Yast.import "Storage"
      Yast.import "InstData"

      @test_mode = WFM.Args.include?("test")

      show_disk_for_image_dialog

      ret = nil
      disk = nil

      continue_buttons = [:next, :back, :close, :abort]
      while !continue_buttons.include?(ret)
        ret = UI.UserInput

        if ret == :next
          disk = UI.QueryWidget(Id(:disk), :Value)
          ret = WFM.CallFunction("inst_doit", [])
          if ret == :next
            InstData.image_target_disk = disk
          else
            ret = nil
          end
        elsif ret == :abort
          ret = nil unless Popup.ConfirmAbort(:painless)
        end
      end

      ret
    end

    private

    def disks_to_use
      target_map = Storage.GetTargetMap
      Builtins.y2milestone("TM: %1", target_map)
      # FIXME: move blacklist to Storage
      used_by_blacklist = [:CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART]
      target_map.select do | _key, value |
        Storage.IsDiskType(value["type"]) && (!used_by_blacklist.include? value["used_by"])
      end.keys
    end

    def disk_for_image_dialog
      MarginBox(1, 0.5,
        VBox(
          Left(Label(_("Select the disk to deploy the image to."))),
          Left(Label(_("All data on the disk will be lost!!!"))),
          VSpacing(0.5),
          SelectionBox(Id(:disk), _("&Disk to Use"), disks_to_use)
        )
      )
    end

    def disk_for_image_help_text
      _("Select the disk, which the image will be deployed to. " \
        "All data on the disk will be lost and the disk will be " \
        "partitioned as defined in the image.")
    end

    def show_disk_for_image_dialog
      Wizard.SetContents(
        _("Hard Disk for Image Deployment"),
        disk_for_image_dialog,
        disk_for_image_help_text,
        GetInstArgs.enable_back || @test_mode,
        GetInstArgs.enable_next || @test_mode
      )
    end
  end
end

Yast::InstDiskForImageClient.new.main

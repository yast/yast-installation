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

# Module:		inst_prepareprogress.ycp
#
# Authors:		Stanislav Visnovsky (visnov@suse.cz)
#
# Purpose:
# Set up the global progress for the installation.
#
# possible return values: `back, `abort `next
module Yast
  class InstPrepareprogressClient < Client
    def main
      textdomain "installation"
      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "Packages"
      Yast.import "Language"
      Yast.import "SlideShow"
      Yast.import "ImageInstallation"
      Yast.import "StorageClients"
      Yast.import "PackageSlideShow"
      Yast.import "Wizard"
      Yast.import "InstData"

      Builtins.y2milestone("BEGIN of inst_prepareprogress.ycp")

      #hide the RN button and set the release notes for SlideShow (bnc#871158)
      Wizard.HideReleaseNotesButton
      base_product = Pkg.ResolvableDependencies("", :product, "").select { | product |
        (product["status"] == :selected || product["status"] == :installed) && 
        (Mode.normal ? product["category"] == "base" : product["source"] == 0)
      }[0]["name"]
      SlideShow.SetReleaseNotes(InstData.release_notes, base_product)

      Packages.SlideShowSetUp(Language.language)

      SlideShow.OpenDialog
      PackageSlideShow.InitPkgData(true) # FIXME: this is odd!

      # Details (such as images sizes) have to known before initializing the SlideShow
      # but only if Installation from Images is in use
      ImageInstallation.FillUpImagesDetails if Installation.image_installation

      @live_size = 0
      if Mode.live_installation
        @cmd = Builtins.sformat("df -P -k %1", "/")
        Builtins.y2milestone("Executing %1", @cmd)
        @out = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("Output: %1", @out)
        @total_str = Ops.get_string(@out, "stdout", "")
        @total_str = Ops.get(Builtins.splitstring(@total_str, "\n"), 1, "")
        @live_size = Builtins.tointeger(
          Ops.get(
            Builtins.filter(Builtins.splitstring(@total_str, " ")) do |s|
              s != ""
            end,
            2,
            "0"
          )
        )

        # Using df-based progress estimation, is rather faster
        #    may be less precise
        #    see bnc#555288
        #     string cmd = sformat ("du -x -B 1024 -s %1", "/");
        #     y2milestone ("Executing %1", cmd);
        #     map out = (map)SCR::Execute (.target.bash_output, cmd);
        #     y2milestone ("Output: %1", out);
        #     string total_str = out["stdout"]:"";
        #     live_size = tointeger (total_str);
        @live_size = 1024 * 1024 if @live_size == 0 # 1 GB is a good approximation
      end

      @stages = [
        {
          "name"        => "disk",
          "description" => _("Preparing disks..."),
          "value"       => Mode.update ? 0 : 120, # FIXME: 2 minutes
          "units"       => :sec
        },
        {
          "name"        => "images",
          "description" => _("Deploying Images..."),
          # Use 'zero' if image installation is not used
          # BNC #439104
          "value"       => Ops.greater_than(
            @live_size,
            0
          ) ?
            @live_size :
            Installation.image_installation ?
              Ops.divide(ImageInstallation.TotalSize, 1024) :
              0, # kilobytes
          "units"       => :kb
        },
        {
          "name"        => "packages",
          "description" => _("Installing Packages..."),
          # here, we do a hack, because until images are deployed, we cannot determine how many
          # packages will be really installed additionally
          "value"       => Ops.divide(
            Ops.subtract(
              PackageSlideShow.total_size_to_install,
              ImageInstallation.TotalSize
            ),
            1024
          ), # kilobytes
          "units"       => :kb
        },
        {
          "name"        => "finish",
          "description" => _("Finishing Basic Installation"),
          # fixed value
          "value"       => 100,
          "units"       => :sec
        }
      ]

      # own workflow for OEM image deployment
      if InstData.image_target_disk
        @stages = [
          {
            "name"        => "images",
            "description" => _("Deploying Images..."),
            "value"       => 300000, # just make it longer than inst_finish, TODO: better value later
            "units"       => :kb
          },
          {
            "name"        => "finish",
            "description" => _("Finishing Basic Installation"),
            # fixed value
            "value"       => 100,
            "units"       => :sec
          }
        ]
    
      end

      SlideShow.Setup(@stages)

      @ret_val = :auto

      Builtins.y2milestone("END of inst_prepareprogress.ycp")

      @ret_val
    end
  end
end

Yast::InstPrepareprogressClient.new.main

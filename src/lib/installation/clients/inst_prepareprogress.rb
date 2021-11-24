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
      Yast.import "Mode"
      Yast.import "Packages"
      Yast.import "Language"
      Yast.import "SlideShow"
      Yast.import "PackageSlideShow"
      Yast.import "InstData"

      Builtins.y2milestone("BEGIN of inst_prepareprogress.ycp")

      Packages.SlideShowSetUp(Language.language)

      SlideShow.OpenDialog
      PackageSlideShow.InitPkgData(true) # FIXME: this is odd!

      stages = [
        {
          "name"        => "disk",
          "description" => _("Preparing disks..."),
          "value"       => Mode.update ? 0 : 120, # two minutes only when doing partitioning
          "units"       => :sec
        },
        {
          "name"        => "packages",
          "description" => _("Installing Packages..."),
          "value"       => 5*60, # just random number like others, but expect that package installation takes most
          "units"       => :sec
        },
        {
          "name"        => "finish",
          "description" => _("Finishing Basic Installation"),
          # fixed value
          "value"       => 120,
          "units"       => :sec
        }
      ]

      # own workflow for OEM image deployment
      if InstData.image_target_disk
        stages = [
          {
            "name"        => "images",
            "description" => _("Deploying Images..."),
            "value"       => 300_000, # just make it longer than inst_finish, TODO: better value later
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

      SlideShow.Setup(stages)

      Builtins.y2milestone("END of inst_prepareprogress.ycp")

      Builtins.y2milestone("Cleaning memory.")
      Builtins.y2milestone("Memory before:\n#{File.read("/proc/#{Process.pid}/status")}")
      # clean as much memory as possible before doing real installation, because some packages
      # can have memory demanding scripts
      GC.start
      Builtins.y2milestone("Memory after:\n#{File.read("/proc/#{Process.pid}/status")}")

      :auto
    end
  end
end

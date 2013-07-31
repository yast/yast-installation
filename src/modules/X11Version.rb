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

# *************
# FILE          : X11Version.ycp
# ***************
# PROJECT       : YaST2
#               :
# AUTHOR        : Marcus Schäfer <ms@suse.de>
#               :
# BELONGS TO    : YaST2
#               : (X11 integration part using SaX2/ISaX)
#               :
# DESCRIPTION   : Provides a function to determine the _used_ XFree-version
#               : in a running system. Provide information about the
#               : package selection status which may told us:
#               : there is no X11 installed
#               :
#               :
# STATUS        : Development
#  *
#  * $Id$
require "yast"

module Yast
  class X11VersionClass < Module
    def main
      textdomain "installation"

      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "Package"
      Yast.import "Mode"

      #=======================================
      # System Global Variables
      #---------------------------------------
      @version = ""
      @versionLink = ""
      X11Version()
    end

    #=======================================
    # Global Functions
    #---------------------------------------
    #---[ GetVersion ]----//
    def GetVersion
      # ...
      # Set the global variable version to:
      # ""  -   No X11 found
      # "3" -   XFree86 Version 3.x
      # "4" -   XFree86 Version 4.x
      # ---
      # NOTE: This is highly dependent on the X11-infrastructure
      # and must be accommodated to any changes there.
      # ---
      @version = "" # init

      # ...
      # Take a look into the system....
      # ask the libhd for the configuration stuff to this card
      # if there is only one entry pointing to XFree86 version 3
      # XFree86 3 has to be used for this card
      # ---
      gfxcards = Convert.convert(
        SCR.Read(path(".probe.display")),
        :from => "any",
        :to   => "list <map>"
      )
      # more cards -> ver=4
      if Ops.greater_than(Builtins.size(gfxcards), 1)
        @version = "4"
      # one cards -> inspect drivers
      elsif Builtins.size(gfxcards) == 1
        Builtins.foreach(gfxcards) do |gfxcard|
          drivers = Ops.get_list(gfxcard, "x11", [])
          # do we have any 4 driver?
          Builtins.foreach(drivers) do |driver|
            if @version == ""
              @version = "4" if Ops.get_string(driver, "version", "") == "4"
            end
          end
          # do we have any 3 driver?
          Builtins.foreach(drivers) do |driver|
            if @version == ""
              @version = "3" if Ops.get_string(driver, "version", "") == "3"
            end
          end
        end
      end
      # not sure about default
      @version = "4" if @version == ""

      Builtins.y2milestone("xfree_version: <%1>", @version)
      @version
    end

    #---[ X11Version ]----//
    def X11Version
      # ...
      # The module constructor. Sets some proprietary module data defined
      # for public access This is done only once (and automatically)
      # when the module is loaded for the first time
      # ---
      GetVersion()
      nil
    end

    #---[ GetX11Link ]----//
    def GetX11Link
      ret = "4"

      count = 0
      file = Ops.add(Installation.destdir, "/X") # "/usr/X11R6/bin/X";

      while Ops.less_than(count, 10)
        Builtins.y2debug("Inspecting: %1 (%2)", file, count)
        stat = Convert.to_map(SCR.Read(path(".target.lstat"), file))
        islink = Ops.get_boolean(stat, "islink", false)
        Builtins.y2debug("islink=%1 (%2)", islink, stat)
        break if islink == nil || islink == false
        file = Convert.to_string(SCR.Read(path(".target.symlink"), file))
        break if file == nil
        count = Ops.add(count, 1)
      end

      ret = "3" if file != nil && !Builtins.regexpmatch(file, "XFree86")
      Builtins.y2milestone("X link: %1", ret)
      ret
    end

    #---[ have_x11 ]----//
    def have_x11
      # ...
      # check if the required packages are installed
      # ---
      ret = true
      pacs = ["xorg-x11", "yast2-x11", "sax2"]
      # Dont ask for installing packages, just return in autoinst mode
      if Mode.autoinst
        ret = Package.InstalledAll(pacs)
      else
        if !Package.InstallAllMsg(
            pacs,
            # notification 1/2
            _(
              "<p>To access the X11 system, the <b>%1</b> package must be installed.</p>"
            ) +
              # notification 2/2
              _("<p>Do you want to install it now?</p>")
          )
          ret = false
        end
      end
      Builtins.y2milestone("have_x11 = %1", ret)
      ret
    end

    publish :variable => :version, :type => "string"
    publish :variable => :versionLink, :type => "string"
    publish :function => :GetVersion, :type => "string ()"
    publish :function => :X11Version, :type => "void ()"
    publish :function => :GetX11Link, :type => "string ()"
    publish :function => :have_x11, :type => "boolean ()"
  end

  X11Version = X11VersionClass.new
  X11Version.main
end

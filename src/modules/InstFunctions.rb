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

# File:	modules/InstFunctions.rb
# Package:	Installation
# Summary:	Installation functions
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# This library provides functions for installation clients that can be easily tested
#
require "yast"

module Yast
  class InstFunctionsClass < Module
    def main
      textdomain "installation"

      Yast.import "Linuxrc"
    end

    # Returns list of ignored features defined via Linuxrc commandline
    #
    # - Allowed formats are ignore[d][_]feature[s]=$feature1[,$feature2,[...]]
    # - Multiple ignored_features are allowed on one command line
    # - Command and features are case-insensitive
    #
    def IgnoredFeatures
      cmdline = Linuxrc.InstallInf("Cmdline").split
      ignored_features = cmdline.select{ |cmd| cmd =~ /^ignored?_?features?=/i }
      ignored_features.collect! {
        |feature|
        feature.gsub(/^ignored?_?features?=(.*)/i, '\1').downcase.tr("-_", "")
      }
      ignored_features.map{ |f| f.split(',') }.flatten.uniq
    end

    publish :function => :IgnoredFeatures, :type => "list ()"
  end

  InstFunctions = InstFunctionsClass.new
  InstFunctions.main
end

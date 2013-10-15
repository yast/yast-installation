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
    # - Allowed format is ignore[d][_]feature[s]=$feature1[,$feature2,[...]]
    # - Multiple ignored_features are allowed on one command line
    # - Command and features are case-insensitive and all dashes
    #   and underscores are ignored
    #
    # @return [Array] ignored features
    def ignored_features
      return @ignored_features if @ignored_features

      cmdline = Linuxrc.InstallInf("Cmdline").downcase.tr("-_", "").split
      ignored_features = cmdline.select do |cmd|
        cmd =~ /^ignored?features?=/i
      end

      ignored_features.collect! do |feature|
        feature.gsub(/^ignored?features?=(.*)/i, '\1')
      end

      @ignored_features = ignored_features.map{ |f| f.split(',') }.flatten.uniq
    end

    # Resets the stored ignored features
    # Used for easier testing
    def reset_ignored_features
      @ignored_features = nil
    end

    # Returns whether feature was set to be ignored, see ignored_features()
    #
    # @param [String] feature_name
    # @return [Boolean] whether it's ignored
    def feature_ignored?(feature_name)
      ignored_features()

      feature = feature_name.downcase.tr("-_", "")
      @ignored_features.include?(feature)
    end

    publish :function => :ignored_features, :type => "list ()"
    publish :function => :feature_ignored?, :type => "boolean (string)"
  end

  InstFunctions = InstFunctionsClass.new
  InstFunctions.main
end

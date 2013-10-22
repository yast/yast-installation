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
    # - Allowed format is ign.o.re[d][_]feature[s]=$feature1[,$feature2,[...]]
    # - Multiple ignored_features are allowed on one command line
    # - Command and features are case-insensitive and all dashes,
    #   underscores and dots are ignored, see #polish
    # - If entries are also mentioned in PTOptions, they do not appear in
    #   'Cmdline' but as separate entries,
    #   see http://en.opensuse.org/SDB:Linuxrc#p_ptoptions
    #
    # @return [Array] ignored features
    def ignored_features
      return @ignored_features if @ignored_features

      # Features defined as individual entries in install.inf
      features_keys = Linuxrc.keys.select do |key|
        polish!(key) =~ /^ignored?features?$/
      end

      unparsed_features = features_keys.map{
        |key|
        polish!(Linuxrc.InstallInf(key))
      }

      # Features mentioned in 'Cmdline' entry
      cmdline = polish!(Linuxrc.InstallInf("Cmdline")).split
      cmdline_features = cmdline.select do |cmd|
        cmd =~ /^ignored?features?=/i
      end

      cmdline_features = cmdline_features.collect! do |feature|
        feature.gsub(/^ignored?features?=(.*)/i, '\1')
      end

      # Both are supported together
      ignored_features = unparsed_features + cmdline_features
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
      if feature_name == nil
        Builtins.y2warning("Undefined feature to check")
        return false
      end

      feature = polish!(feature_name)
      ignored_features.include?(feature)
    end

    publish :function => :ignored_features, :type => "list ()"
    publish :function => :feature_ignored?, :type => "boolean (string)"

  private

    # Removes unneeded characters from the given string
    # for easier handling
    def polish!(feature)
      feature.downcase.tr("-_\.", "")
    end
  end

  InstFunctions = InstFunctionsClass.new
  InstFunctions.main
end

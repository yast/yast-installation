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
    include Yast::Logger
    def main
      textdomain "installation"

      Yast.import "Linuxrc"
      Yast.import "AutoinstConfig"
      Yast.import "Stage"
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "Profile"
    end

    # Returns list of ignored features defined via Linuxrc commandline
    #
    # - Allowed format is ignore[d][_]feature[s]=$feature1[,$feature2,[...]]
    # - Multiple ignored_features are allowed on one command line
    # - Command and features are case-insensitive and all dashes,
    #   underscores and dots are ignored to be compatible with Linuxrc,
    #   see #polish and http://en.opensuse.org/SDB:Linuxrc#Passing_parameters
    # - If entries are also mentioned in PTOptions, they do not appear in
    #   'Cmdline' but as separate entries,
    #   see http://en.opensuse.org/SDB:Linuxrc#p_ptoptions
    #
    # @return [Array] ignored features
    def ignored_features
      return @ignored_features if @ignored_features

      # Features defined as individual entries in install.inf
      features_keys = Linuxrc.keys.select do |key|
        polish(key) =~ /^ignored?features?$/
      end

      unparsed_features = features_keys.map do |key|
        polish(Linuxrc.InstallInf(key))
      end

      # Features mentioned in 'Cmdline' entry, it might not be defined (bnc#861465)
      cmdline = polish(Linuxrc.InstallInf("Cmdline") || "").split
      cmdline_features = cmdline.select do |cmd|
        cmd =~ /^ignored?features?=/i
      end

      cmdline_features.collect! do |feature|
        feature.gsub(/^ignored?features?=(.*)/i, '\1')
      end

      # Both are supported together
      ignored_features = unparsed_features + cmdline_features
      @ignored_features = ignored_features.map { |f| f.split(",") }.flatten.uniq
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
      if feature_name.nil?
        Builtins.y2warning("Undefined feature to check")
        return false
      end

      feature = polish(feature_name)
      ignored_features.include?(feature)
    end

    # Determines if the second stage should be executed
    #
    # Checks Mode, AutoinstConfig and ProductControl to decide if it's
    # needed.
    #
    # @return [Boolean] 'true' if it's needed; 'false' otherwise.
    def second_stage_required?
      return false unless Stage.initial

      # the current one is 'initial'
      if (Mode.autoinst || Mode.autoupgrade) && !AutoinstConfig.second_stage
        run_second_stage = false
        Builtins.y2milestone("Autoyast: second stage is disabled")
      else
        # after reboot/kexec it would be 'continue'
        stage_to_check = "continue"

        # for matching the control file
        mode_to_check = Mode.mode

        Builtins.y2milestone(
          "Checking RunRequired (%1, %2)",
          stage_to_check,
          mode_to_check
        )
        run_second_stage = ProductControl.RunRequired(stage_to_check, mode_to_check)
      end

      run_second_stage
    end
    alias_method :second_stage_required, :second_stage_required?

    # Determine whether the installer update has been explicitly enabled by
    # linuxrc or by the AY profile.
    #
    # return [Boolean] true if enabled explicitly; false otherwise
    def self_update_explicitly_enabled?
      # Linuxrc always export SelfUpdate with the default value even if not has
      # been set by the user. For that reason we need to check the cmdline for
      # knowing whether the user has requested the self update explicitly.
      in_cmdline = Linuxrc.value_for("self_update")
      if in_cmdline && in_cmdline != "0"
        log.info("Self update was enabled explicitly by linuxrc cmdline")
        return true
      end

      return false unless Mode.auto

      profile = Yast::Profile.current
      in_profile = profile.fetch("general", {}).fetch("self_update", false)
      log.info("Self update was enabled explicitly by the AY profile") if in_profile
      in_profile
    end

    publish function: :ignored_features, type: "list ()"
    publish function: :feature_ignored?, type: "boolean (string)"
    publish function: :second_stage_required, type: "boolean ()"

  private

    # Removes unneeded characters from the given string
    # for easier handling
    #
    # These unneeded characters are entered by user on Linuxrc commandline
    # we remove them everywhere, and down-case all strings so it's very easy
    # to match given features with user-entered strings
    #
    # @param [String] feature
    # @return [String] polished feature
    def polish(feature)
      feature.downcase.tr("-_\.", "")
    end
  end

  InstFunctions = InstFunctionsClass.new
  InstFunctions.main
end

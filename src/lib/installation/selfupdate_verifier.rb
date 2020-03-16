# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "installation/instsys_packages"
require "y2packager/repository"

module Installation
  # This class does some self-update repository sanity checks to avoid
  # applying a wrong self update repository (specified by user).
  class SelfupdateVerifier
    include Yast::Logger

    # We only check the version of these packages, the reason for a fixed
    # list is that these packages are maintained by us and their version
    # is under our control.
    #
    # We do not care about the other packages, in theory there might be
    # valid reasons for downgrading them. With these YaST packages we can
    # go back to the previous state but but still increase the version number.
    #
    # We can also check the "too new" packages because the YaST package versions
    # are bound to specific SP release (e.g. 4.1.x in SP1, 4.2.x in SP2).
    # So the major and minor version parts must not be changed during self update.
    VERIFIED_PACKAGES = [
      "autoyast2-installation",
      "yast2",
      "yast2-installation",
      "yast2-packager",
      "yast2-pkg-bindings",
      "yast2-registration",
      "yast2-storage-ng",
      "yast2-update"
    ].freeze

    # Constructor
    # @param repositories [Array<UpdateRepository>] the self-update repositories
    # @param instsys_packages [Array<Y2Packager::Package>] the installed packages
    #   in the current inst-sys
    def initialize(repositories, instsys_packages)
      @instsys_packages = instsys_packages.select do |p|
        VERIFIED_PACKAGES.include?(p.name)
      end

      # the selfupdate repo might provide the same package in several versions,
      # find the latest one

      # group the same packages together
      packages = {}

      repositories.each do |repo|
        repo.packages.each do |p|
          next unless VERIFIED_PACKAGES.include?(p.name)

          if packages[p.name]
            packages[p.name] << p
          else
            packages[p.name] = [p]
          end
        end
      end

      # for each package find the highest version
      @selfupdate_packages = packages.values.map do |pkgs|
        pkgs.max { |a, b| Yast::Pkg.CompareVersions(a.version, b.version) }
      end
    end

    # check for downgraded packages, e.g. using the SP1 updates in the SP2 installer
    #
    # @return [Array<Y2Packager::Resolvable>] List of downgraded packages
    def downgraded_packages
      packages = filter_self_updates do |inst_sys_pkg, update_pkg|
        # -1 = "update_pkg" is older than "inst_sys_pkg" (0 = the same, 1 = newer)
        Yast::Pkg.CompareVersions(update_pkg.version, inst_sys_pkg.version) == -1
      end

      log.warn("Found downgraded self-update packages: #{packages} ") unless packages.empty?
      packages
    end

  private

    # filter the self update packages using a block
    def filter_self_updates(&block)
      selfupdate_packages.select do |s|
        pkg = instsys_package(s.name)
        # if not in inst-sys
        next false unless pkg

        block.call(pkg, s)
      end
    end

    # find the installed package in the inst-sys
    # @param name [String] name of the package
    def instsys_package(name)
      instsys_packages.find { |p| p.name == name }
    end

    attr_reader :instsys_packages, :selfupdate_packages
  end
end

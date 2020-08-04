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

require "yaml"
require "yast"

Yast.import "Pkg"
Yast.import "Report"

module Installation
  # This class represents an old package which should not be installed by users.
  class OldPackage
    include Yast::Logger

    attr_reader :name, :version, :arch, :message

    # @param name [String] name of the package
    # @param version [String] version of the package
    # @param arch [String] architecture, e.g. "x86_64"
    # @param message [String] the error message displayed to the user
    #  when an old package is selected
    def initialize(name:, version:, arch:, message:)
      @name = name
      @version = version
      @arch = arch
      @message = message
    end

    # Finds the currently selected old package, if none or newer is selected then
    # it returns `nil`.
    # @return [Hash,nil] The selected old package or nil.
    def selected_old
      packages = Yast::Pkg.ResolvableProperties(name, :package, "")

      # -1 = the second version (the selected package) is newer
      packages.find do |p|
        p["status"] == :selected && p["arch"] == arch &&
          Yast::Pkg.CompareVersions(version, p["version"]) != -1
      end
    end

    # Reads the old package configuration files and creates the respective
    # OldPackage objects. It reads all YAML files from the subdirectories.
    # @param paths [Array<String>,nil] The list of directories which are scanned
    #  for the YAML configuration files. If `nil` then the default YaST paths
    #  are used.
    # @return [Array<Installation::OldPackage>] Configured old packages,
    #  empty list if no configuration is specified
    # @see See the data/old_packages/*.yml example file.
    def self.read(paths = nil)
      # unfortunately we cannot use Yast::Directory.find_data_file
      # here because it needs an exact file name, it does not accept a glob,
      # use Yast.y2paths to honor the Y2DIR setting
      data_paths = paths || Yast.y2paths.map { |p| File.join(p, "data", "old_packages") }
      data_paths.select { |p| File.directory?(p) }

      log.debug "Found data directories: #{data_paths.inspect}"

      data_files = data_paths.each_with_object([]) do |p, obj|
        # find all *.yml and *.yaml files
        obj.concat(Dir[File.join(p, "*.y{a,}ml")])
      end

      log.debug "Found data files: #{data_files.inspect}"

      # remove the duplicates, this ensures the Y2DIR precedence
      data_files.uniq! do |f|
        File.basename(f)
      end

      log.debug "Unique data files: #{data_files.inspect}"

      data_files.each_with_object([]) do |f, arr|
        log.info "Loading file #{f.inspect}"

        config = YAML.load_file(f)
        message = config["message"] || ""
        packages = config["packages"] || []

        packages.each do |p|
          arr << new(
            name:    p["name"],
            version: p["version"],
            arch:    p["arch"],
            message: message
          )
        end
      end
    end
  end
end

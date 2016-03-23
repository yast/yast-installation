# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------
require "yast"
require "tempfile"
require "pathname"

module Installation
  # Represents a update repository
  #
  # @example Fetching and applying an update
  #   repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #   repo.fetch
  #   repo.apply
  #
  # @example Fetching and applying to non-standard places
  #   repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #   repo.fetch(Pathname("/downloading"))
  #   repo.apply(Pathname("/updates"))
  class UpdateRepository
    include Yast::Logger

    attr_reader :uri, :repo_id, :paths, :instsys_parts_path

    class NotFound < StandardError; end
    class CouldNotBeApplied < StandardError; end
    class UpdatesNotFetched < StandardError; end
    class CouldNotExtractUpdate < StandardError; end
    class CouldNotMountUpdate < StandardError; end
    class CouldNotSquashUpdate < StandardError; end

    # Command to extract an RPM which is part of an update
    EXTRACT_CMD = "rpm2cpio %<source>s | cpio --quiet --sparse -dimu --no-absolute-filenames"
    # Command to build an squashfs filesystem containing all updates
    SQUASH_CMD = "mksquashfs %<dir>s %<file>s -noappend -no-progress"
    # Command to mount squashfs filesystem
    MOUNT_CMD = "mount %<source>s %<target>s"
    # Command to apply the DUD disk to inst-sys
    APPLY_CMD = "/etc/adddir %<source>s /" # openSUSE/installation-images
    # Directory to store the update
    DEFAULT_STORE_PATH = Pathname("/download")
    # Directory to mount the update
    DEFAULT_MOUNT_PATH = Pathname("/mounts")
    # Default instsys.parts file
    DEFAULT_INSTSYS_PARTS = Pathname("/etc/instsys.parts")

    # Constructor
    #
    # @param uri                [URI]      Repository URI
    # @param instsys_parts_path [Pathname] Path to instsys.parts file
    def initialize(uri, instsys_parts_path = DEFAULT_INSTSYS_PARTS)
      Yast.import "Pkg"

      @uri = uri
      @repo_id = add_repo
      @paths = nil
      @packages = nil
      @instsys_parts_path = instsys_parts_path
    end

    # Retrieves the list of packages to install
    #
    # Only packages in the update repository are considered.  Packages are
    # sorted by name (alphabetical order).
    #
    # @return [Array<Hash>] List of packages to install
    #
    # @see Yast::Pkg.ResolvableProperties
    def packages
      return @packages unless @packages.nil?
      candidates = Yast::Pkg.ResolvableProperties("", :package, "")
      @packages = candidates.select { |p| p["source"] == repo_id }.sort_by! { |a| a["name"] }
      log.info "Considering #{@packages.size} packages: #{@packages}"
      @packages
    end

    # Fetch updates
    #
    # Updates will be stored in the given directory. They'll be named
    # sequentially using three digits and the prefix 'yast'. For example:
    # yast_000, yast_001 and so on.
    #
    # The object will track updates so they can be applied later.
    #
    # @param path [Pathname] Directory to store the updates
    # @return [Pathname] Paths to the updates
    #
    # @see #fetch_package
    # @see #paths
    # @see DEFAULT_STORE_PATH
    def fetch(path = DEFAULT_STORE_PATH)
      @paths = packages.map do |package|
        fetch_package(package, path)
      end
    end

    # Apply updates to inst-sys
    #
    # It happens in two phases (for each update/package):
    #
    # * Mount the squashfs filesystem
    # * Add files/directories to inst-sys using the /etc/adddir script
    #
    # @param mount_path [Pathname] Directory to mount the update
    #
    # @raise UpdateNotFetched
    #
    # @see #mount_squashfs
    # @see #adddir
    def apply(mount_path = DEFAULT_MOUNT_PATH)
      raise UpdatesNotFetched if paths.nil?
      paths.each do |path|
        mountpoint = next_name(mount_path, length: 4)
        mount_squashfs(path, mountpoint)
        adddir(mountpoint)
        update_instsys_parts(path, mountpoint)
      end
    end

    # Release the repository
    #
    # @param [Integer] Repository Id
    def cleanup
      Yast::Pkg.SourceDelete(repo_id)
    end

  private

    # Fetch and build an squashfs filesytem for a given package
    #
    # @param package [Hash] Package to retrieve
    # @param dir     [Pathname] Path to store the squashed filesystems
    #
    # @see #packages
    # @see #apply
    def fetch_package(package, dir)
      workdir = Dir.mktmpdir
      package_path = Yast::Pkg.SourceProvideFile(repo_id, 0, package["path"])
      extract(package_path, workdir)
      squashed_path = next_name(dir, length: 3)
      build_squashfs(workdir, squashed_path)
      squashed_path
    ensure
      FileUtils.remove_entry(workdir)
    end

    # Extract a RPM content to a given directory
    #
    # @param package_path [String]   RPM local path
    # @param dir          [Pathname] Directory to extract the RPM contents
    def extract(package_path, dir)
      Dir.chdir(dir) do
        cmd = format(EXTRACT_CMD, source: package_path)
        out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
        log.info("Extracting package #{package_path}: #{out}")
        CouldNotExtractUpdate unless out["exit"].zero?
      end
    end

    # Build an squashfs filesystem from a directory
    #
    # @param dir  [Pathname] Path to include in the squashed file
    # @param file [Pathname] Path to write the squashed file
    #
    # @raise CouldNotSquashUpdate
    def build_squashfs(dir, file)
      cmd = format(SQUASH_CMD, dir: dir, file: file.to_s)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Squashing packages into #{file}: #{out}")
      CouldNotSquashUpdate unless out["exit"].zero?
    end

    # Add the repository to libzypp sources
    #
    # @return [Integer] Repository ID
    #
    # @raise NotFound
    def add_repo
      new_repo_id = Yast::Pkg.RepositoryAdd("base_urls" => [uri.to_s],
                                            "enabled" => true, "autorefresh" => true)
      if Yast::Pkg.SourceRefreshNow(new_repo_id) && Yast::Pkg.SourceLoad
        new_repo_id
      else
        raise NotFound
      end
    end

    # Mount the squashed filesystem containing updates
    #
    # @param path [Pathname] Mountpoint
    #
    # @raise CouldNotMountUpdate
    #
    # @see MOUNT_CMD
    def mount_squashfs(file, mountpoint)
      FileUtils.mkdir(mountpoint) unless mountpoint.exist?
      cmd = format(MOUNT_CMD, source: file.to_s, target: mountpoint.to_s)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Mounting squashfs system #{file} as #{mountpoint}: #{out}")
      CouldNotMountUpdate unless out["exit"].zero?
    end

    # Add files/directories to the inst-sys
    #
    # @raise CouldNoteBeApplied
    #
    # @see APPLY_CMD
    def adddir(path)
      cmd = format(APPLY_CMD, source: path)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Updating inst-sys '#{cmd}': #{out}")
      raise CouldNotBeApplied unless out["exit"].zero?
    end

    # Calculates the next filename
    #
    # It finds the next name (formed by digits) to be used
    # in a given directory. For example, '000', '001', etc.
    #
    # @param basedir [Pathname] Directory
    # @param prefix  [String]   Name prefix
    # @param length  [Integer]  Name's length
    # @return [Pathname] File name
    def next_name(basedir, prefix: "yast_", length: 3)
      files = Pathname.glob(basedir.join("*")).map(&:basename)
      dirs = files.map(&:to_s).grep(/\A#{prefix}\d+\Z/)
      dirs = dirs.map { |d| d.sub(prefix, "") } unless prefix.empty?
      number = dirs.empty? ? 0 : dirs.map(&:to_i).max + 1
      basedir.join(format("#{prefix}%0#{length}d", number))
    end

    # Register a mounted filesystem in instsys.parts file
    #
    # @param path       [Pathname] Filesystem to mount
    # @param mountpoint [Pathname] Mountpoint
    #
    # @see instsys_parts_path
    def update_instsys_parts(path, mountpoint)
      instsys_parts_path.open("a") do |f|
        f.puts "#{path.relative_path_from(Pathname("/"))} #{mountpoint}"
      end
    end
  end
end

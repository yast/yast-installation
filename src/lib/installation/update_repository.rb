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
require "fileutils"

module Installation
  # Represents a update repository to be used during self-update
  # (check doc/SELF_UPDATE.md for details).
  #
  # @example Fetching and applying an update
  #   repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #   repo.fetch
  #   repo.apply
  #   repo.cleanup
  #
  # @example Fetching and applying to non-standard places
  #   repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #   repo.fetch(Pathname("/downloading"))
  #   repo.apply(Pathname("/updates"))
  #   repo.cleanup
  class UpdateRepository
    include Yast::Logger

    # @return [URI] URI of the repository
    attr_reader :uri
    # @return [Fixnum] yast2-pkg-bindings ID of the repository
    attr_reader :repo_id
    # @return [Pathname] Registry of inst-sys updated parts
    attr_reader :instsys_parts_path
    # @return [Array<Pathname>] local paths of updates fetched from the repo
    attr_reader :update_files

    # A valid repository was not found (altough the URL exists,
    # repository type cannot be determined).
    class ValidRepoNotFound < StandardError; end

    # Error while trying to fetch the update (used to group fetching
    # errors).
    class FetchError < StandardError; end

    # The repository could not be probed (it includes network errors).
    class CouldNotProbeRepo < StandardError; end

    # The repository could not be refreshed, so metadata is not
    # available.
    class CouldNotRefreshRepo < FetchError; end

    # Updates could not be fetched (missing packages, network errors,
    # content from packages could not be extracted and so on).
    class CouldNotFetchUpdate < FetchError; end

    # The squashed filesystem could not be mounted.
    class CouldNotMountUpdate < StandardError; end

    # The inst-sys could not be updated.
    class CouldNotBeApplied < StandardError; end

    # Updates should be fetched before calling to #apply.
    class UpdatesNotFetched < StandardError; end

    #
    # Internal exceptions (handled internally)
    #
    # Some package from the update repository is missing (converted to
    # CouldNotFetchUpdate).
    class PackageNotFound < FetchError; end
    # Some package could not be extracted (converted to
    # CouldNotFetchUpdate).
    class CouldNotExtractPackage < FetchError; end
    # The squashed filesystem could not be created (converted to
    # CouldNotFetchUpdate).
    class CouldNotSquashPackage < FetchError; end

    # Constructor
    #
    # @param uri                [URI]      Repository URI
    # @param instsys_parts_path [Pathname] Path to instsys.parts registry
    def initialize(uri, instsys_parts_path = Pathname("/etc/instsys.parts"))
      Yast.import "Pkg"

      @uri = uri
      @repo_id = add_repo
      @update_files = []
      @packages = nil
      @instsys_parts_path = instsys_parts_path
    end

    # Retrieves the list of packages to install
    #
    # Only packages in the update repository are considered. Packages are
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
    # If a known error occurs, it will be converted to a CouldNotFetchUpdate
    # exception.
    #
    # @param path [Pathname] Directory to store the updates
    # @return [Pathname] Paths to the updates
    #
    # @see #fetch_package
    # @see #paths
    # @see #update_files
    #
    # @raise CouldNotFetchUpdate
    def fetch(path = Pathname("/download"))
      packages.each_with_object(update_files) do |package, files|
        files << fetch_package(package, path)
      end
    rescue PackageNotFound, CouldNotExtractPackage, CouldNotSquashPackage => e
      log.error("Could not fetch update: #{e.inspect}. Rolling back.")
      remove_update_files
      raise CouldNotFetchUpdate
    end

    # Remove fetched packages
    #
    # Remove fetched packages from the filesystem. This method won't work
    # if the update is already applied.
    def remove_update_files
      log.info("Removing update files: #{update_files}")
      update_files.each do |path|
        FileUtils.rm_f(path)
      end
      update_files.clear
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
    # @raise UpdatesNotFetched
    #
    # @see #mount_squashfs
    # @see #adddir
    def apply(mount_path = Pathname("/mounts"))
      raise UpdatesNotFetched if update_files.nil?
      update_files.each do |path|
        mountpoint = next_name(mount_path, length: 4)
        mount_squashfs(path, mountpoint)
        adddir(mountpoint)
        update_instsys_parts(path, mountpoint)
      end
    end

    # Clean-up
    #
    # Release the repository
    def cleanup
      Yast::Pkg.SourceDelete(repo_id)
    end

  private

    # Fetch and build a squashfs filesytem for a given package
    #
    # @param package [Hash] Package to retrieve
    # @param dir     [Pathname] Path to store the squashed filesystems
    #
    # @see #packages
    # @see #apply
    #
    # @raise PackageNotFound
    def fetch_package(package, dir)
      Dir.mktmpdir do |workdir|
        fun_ref = Yast::FunRef.new(method(:copy_file_to_tempfile), "boolean(string)")
        package_path = Yast::Pkg.ProvidePackage(repo_id, package["name"], fun_ref)
        if package_path.nil?
          log.error("Package #{package} could not be retrieved.")
          raise PackageNotFound
        end
        extract(Pathname(package_path), workdir)
        squashed_path = next_name(dir, length: 3)
        build_squashfs(workdir, squashed_path)
        squashed_path
      end
    end

    # Copy a given package to a tempfile
    #
    # This method will be used as a callback for Yast::Pkg.ProvidePackage
    #
    # @param source [String] Path to the original file
    # @return [String] Path to the tempfile
    def copy_file_to_tempfile(source)
      tempfile = Tempfile.new(File.basename(source))
      tempfile.close
      log.info("Copying '#{source}' to '#{tempfile.path}")
      FileUtils.cp(source, tempfile.path)
      tempfile.path
    end

    # Command to extract an RPM which is part of an update
    EXTRACT_CMD = "rpm2cpio %<source>s | cpio --quiet --sparse -dimu --no-absolute-filenames"

    # Extract a RPM contents to a given directory
    #
    # @param package_path [String]   RPM local path
    # @param dir          [Pathname] Directory to extract the RPM contents
    #
    # @raise CouldNotExtractPackage
    def extract(package_path, dir)
      Dir.chdir(dir) do
        cmd = format(EXTRACT_CMD, source: package_path)
        out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
        log.info("Extracting package #{package_path}: #{out}")
        raise CouldNotExtractPackage unless out["exit"].zero?
      end
    end

    # Command to build an squashfs filesystem containing all updates
    SQUASH_CMD = "mksquashfs %<dir>s %<file>s -noappend -no-progress"

    # Build a squashfs filesystem from a directory
    #
    # @param dir  [Pathname] Path to include in the squashed file
    # @param file [Pathname] Path to write the squashed file
    #
    # @raise CouldNotSquashPackage
    def build_squashfs(dir, file)
      cmd = format(SQUASH_CMD, dir: dir, file: file.to_s)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Squashing packages into #{file}: #{out}")
      raise CouldNotSquashPackage unless out["exit"].zero?
    end

    # Add the repository to libzypp sources
    #
    # @return [Integer] Repository ID
    #
    # @raise ValidRepoNotFound
    # @raise CouldNotProbeRepo
    # @raise CouldNotRefreshRepo
    def add_repo
      status = repo_status
      raise ValidRepoNotFound if status == :not_found
      raise CouldNotProbeRepo if status == :error
      new_repo_id = Yast::Pkg.RepositoryAdd("base_urls" => [uri.to_s],
                                            "enabled" => true, "autorefresh" => true)
      log.info("Added repository #{uri} as '#{new_repo_id}'")
      if Yast::Pkg.SourceRefreshNow(new_repo_id) && Yast::Pkg.SourceLoad
        new_repo_id
      else
        log.error("Could not get metadata from repository '#{new_repo_id}'")
        raise CouldNotRefreshRepo
      end
    end

    # Check the status of the repository
    #
    # @return [Symbol] :ok the repository looks good
    #                  :not_found if repository could not be identified;
    #                  :error if some error occurred (ie. network problems)
    def repo_status
      # According to Pkg.RepositoryProbe documentation:
      # * "NONE" -> type cannot be determined
      # * nil -> an error ocurred (resolving a hostname, for example)
      probed = Yast::Pkg.RepositoryProbe(uri.to_s, "/")
      log.info("Probed repository #{uri}: #{probed}")
      if probed == "NONE"
        :not_found
      elsif probed.is_a?(String)
        :ok
      else
        log.warn("Status of repository at #{uri} cannot be determined")
        :error
      end
    end

    # Command to mount squashfs filesystem
    MOUNT_CMD = "mount %<source>s %<target>s"

    # Mount the squashed filesystem containing updates
    #
    # @param path [Pathname] Mountpoint
    #
    # @raise CouldNotMountUpdate
    #
    # @see MOUNT_CMD
    def mount_squashfs(file, mountpoint)
      FileUtils.mkdir_p(mountpoint) unless mountpoint.exist?
      cmd = format(MOUNT_CMD, source: file.to_s, target: mountpoint.to_s)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Mounting squashfs system #{file} as #{mountpoint}: #{out}")
      raise CouldNotMountUpdate unless out["exit"].zero?
    end

    # Command to apply the DUD disk to inst-sys
    APPLY_CMD = "/etc/adddir %<source>s /" # openSUSE/installation-images

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
    # It finds the next name (formed by digits) to be used in a given
    # directory. For example, 'yast_000', 'yast_001', etc.
    #
    # @param basedir [Pathname] Directory
    # @param prefix  [String]   Prefix
    # @param length  [Integer]  Length
    # @return [Pathname] File name
    def next_name(basedir, prefix: "yast_", length: 3)
      files = Pathname.glob(basedir.join("*")).map(&:basename)
      dirs = files.map(&:to_s).grep(/\A#{prefix}\d+\Z/)
      number = dirs.size
      basedir.join(format("#{prefix}%0#{length}d", number))
    end

    # Register a mounted filesystem in instsys.parts file
    #
    # It's intended to help when debugging problems in inst-sys.
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

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

require "packages/package_downloader"
require "packages/package_extractor"

Yast.import "Pkg"
Yast.import "Progress"
Yast.import "URL"

module Installation
  # Represents a update repository to be used during self-update
  # (check doc/SELF_UPDATE.md for details).
  #
  # @example Fetching and applying an update
  #   begin
  #     repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #     repo.fetch
  #     repo.apply
  #   ensure
  #     repo.cleanup
  #   end
  #
  # @example Fetching and applying to non-standard places
  #   begin
  #     repo = UpdateRepository.new(URI("http://update.opensuse.org/42.1"))
  #     repo.fetch(Pathname("/downloading"))
  #     repo.apply(Pathname("/updates"))
  #   ensure
  #     repo.cleanup
  #   end
  class UpdateRepository
    include Yast::Logger
    include Yast::I18n

    # Where the repository information comes from
    #
    # * :default: Default
    # * :user:    User defined
    ORIGINS = [:default, :user].freeze
    # Path to instsys.parts registry
    INSTSYS_PARTS_PATH = Pathname("/etc/instsys.parts")

    # @return [URI] URI of the repository
    attr_reader :uri
    # @return [Array<Pathname>] local paths of updates fetched from the repo
    attr_reader :update_files
    # @return [Symbol] Repository origin. @see ORIGINS
    attr_reader :origin
    # @return [Integer] Repository ID
    attr_writer :repo_id
    private :repo_id=

    # A valid repository was not found (although the URL exists,
    # repository type cannot be determined).
    class NotValidRepo < StandardError; end

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

    # Not valid origin for the repository
    class UnknownOrigin < StandardError; end

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
    # @param origin             [Symbol]   Repository origin (@see ORIGINS)
    def initialize(uri, origin = :default)
      textdomain "installation"

      @uri = uri
      @update_files = []
      @packages = nil
      raise UnknownOrigin unless ORIGINS.include?(origin)
      @origin = origin
    end

    # Returns the repository ID
    #
    # As a potential side-effect, the repository will be added to libzypp (if it
    # was not added yet) in order to get the ID.
    #
    # @return [Fixnum] yast2-pkg-bindings ID of the repository
    #
    # @see add_repo
    def repo_id
      add_repo
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
      add_repo
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
    # A progress is displayed when the packages are downloaded.
    # The progress can be disabled by calling `Yast::Progress.set(false)`.
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
      init_progress

      packages.each_with_object(update_files).with_index do |(package, files), index|
        update_progress(100 * index / packages.size)
        files << fetch_package(package, path)
      end
    rescue Packages::PackageDownloader::FetchError, Packages::PackageExtractor::ExtractionFailed,
           CouldNotSquashPackage => e

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
    # @note The current implementation creates one squashfs image per package
    # and mounting a squashfs image consumes one loop device (/dev/loop*).
    # Inst-sys has by default 64 loop devices, but some of them already used,
    # in an extreme case we might run out of loop devices.
    #
    # On the other hand downloading and unpacking all packages at once might
    # require a lot of memory, the installer could crash on a system with
    # small memory.
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
      Yast::Pkg.SourceReleaseAll
      Yast::Pkg.SourceDelete(repo_id)
      # make sure it's also removed from disk
      Yast::Pkg.SourceSaveAll
    end

    # Determine whether the repository is empty or not
    #
    # @return [Boolean] true if the repository is empty; false otherwise.
    #
    # @see #packages
    def empty?
      packages.empty?
    end

    # Returns whether is a user defined repository
    #
    # @return [Boolean] true if the repository is user-defined empty;
    #                   false otherwise.
    def user_defined?
      origin == :user
    end

    # Determines whether the URI of the repository is remote or not
    #
    # @return [Boolean] true if the repository is using a 'remote URI';
    #                   false otherwise.
    #
    # @see Pkg.UrlSchemeIsRemote
    def remote?
      Yast::Pkg.UrlSchemeIsRemote(uri.scheme)
    end

    # Redefines the inspect method to avoid logging passwords
    #
    # @return [String] Debugging information
    def inspect
      "#<Installation::UpdateRepository> @uri=\"#{safe_uri}\" @origin=#{@origin.inspect}"
    end

  private

    # Fetch and build a squashfs filesytem for a given package
    #
    # @param package [Hash] Package to retrieve
    # @param dir     [Pathname] Path to store the squashed filesystems
    # @return [Pathname] Path where the file is stored
    #
    # @see #packages
    # @see #apply
    #
    # @raise PackageNotFound
    def fetch_package(package, dir)
      tempfile = Tempfile.new(package["name"])
      tempfile.close
      Dir.mktmpdir do |workdir|
        downloader = Packages::PackageDownloader.new(repo_id, package["name"])
        downloader.download(tempfile.path.to_s)

        extractor = Packages::PackageExtractor.new(tempfile.path.to_s)
        extractor.extract(workdir)

        build_squashfs(workdir, next_name(dir, length: 3))
      end
    ensure
      tempfile.unlink
    end

    # Command to build an squashfs filesystem containing all updates
    SQUASH_CMD = "mksquashfs %<dir>s %<file>s -noappend -no-progress".freeze

    # Build a squashfs filesystem from a directory
    #
    # @param dir  [Pathname] Path to include in the squashed file
    # @param file [Pathname] Path to write the squashed file
    # @return [Pathname] Path where the squashed file is written (same as +file+)
    #
    # @raise CouldNotSquashPackage
    def build_squashfs(dir, file)
      cmd = format(SQUASH_CMD, dir: dir, file: file.to_s)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      log.info("Squashing packages into #{file}: #{out}")
      raise CouldNotSquashPackage unless out["exit"].zero?
      file
    end

    # Add the repository to libzypp sources
    #
    # If the repository was already added, it will just simply return
    # the repository ID.
    #
    # @return [Integer] Repository ID
    #
    # @raise NotValidRepo
    # @raise CouldNotProbeRepo
    # @raise CouldNotRefreshRepo
    def add_repo
      return @repo_id unless @repo_id.nil?
      status = repo_status
      raise NotValidRepo if status == :not_found
      raise CouldNotProbeRepo if status == :error
      new_repo_id = Yast::Pkg.RepositoryAdd("base_urls" => [uri.to_s],
                                            "enabled" => true, "autorefresh" => true)
      log.info("Added repository #{uri} as '#{new_repo_id}'")
      if Yast::Pkg.SourceRefreshNow(new_repo_id) && Yast::Pkg.SourceLoad
        self.repo_id = new_repo_id
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
    MOUNT_CMD = "mount %<source>s %<target>s".freeze

    # Mount the squashed filesystem containing updates
    #
    # @param file [Pathname] file with squashfs content
    # @param mountpoint [Pathname] where to mount
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
    APPLY_CMD = "/etc/adddir %<source>s /".freeze # openSUSE/installation-images

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
    # @see INSTSYS_PARTS_PATH
    def update_instsys_parts(path, mountpoint)
      INSTSYS_PARTS_PATH.open("a") do |f|
        f.puts "#{path.relative_path_from(Pathname("/"))} #{mountpoint}"
      end
    end

    # Initialize the progress
    def init_progress
      # mark the next stage active
      Yast::Progress.NextStage
    end

    # Display the current Progress
    # @param [Fixnum] percent the current progress in range 0..100
    def update_progress(percent)
      Yast::Progress.Step(percent)
    end

    # Returns the URI removing sensitive information
    #
    # @return [String] URI without the password (if present)
    #
    # @see Yast::URL.HidePassword
    def safe_uri
      @safe_uri ||= Yast::URL.HidePassword(uri.to_s)
    end
  end
end

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
require "transfer/file_from_url"

module Installation
  # Represents a driver update disk (DUD)
  #
  # The DUD will be fetched from a given URL.
  class DriverUpdate
    include Yast::I18n # missing in yast2-update
    include Yast::Transfer::FileFromUrl # get_file_from_url

    class NotFound < StandardError; end
    class CouldNotBeApplied < StandardError; end

    # Command to extract the content of the DUD
    EXTRACT_CMD = "gzip -dc %<source>s | cpio --quiet --sparse -dimu --no-absolute-filenames"
    # Command to apply the DUD disk to inst-sys
    APPLY_CMD = "/etc/adddir %<source>s/inst-sys /" # openSUSE/installation-images
    # Command to extract content of a signed (with PGP) DUD
    EXTRACT_SIG_CMD = "gpg --homedir %<homedir>s --batch --no-default-keyring --keyring %<keyring>s " \
      "--ignore-valid-from --ignore-time-conflict --output '%<unpacked>s' '%<source>s'"
    # Command to verify a detached PGP signature
    VERIFY_SIG_CMD = "gpg --homedir %<homedir>s --batch --no-default-keyring --keyring %<keyring>s " \
      "--ignore-valid-from --ignore-time-conflict --verify '%<path>s'"
    # Temporary name for driver updates
    TEMP_FILENAME = "remote.dud"
    # Extension for unpacked driver updates after extracting the PGP signature
    UNPACKED_EXT = ".unpacked"
    # Extension for detached PGP signatures
    SIG_EXT = ".asc"

    attr_reader :uri, :local_path, :keyring, :gpg_homedir

    # Constructor
    #
    # @param uri         [URI]      Driver Update URI
    # @param keyring     [Pathname] Path to keyring to check signatures against
    # @param gpg_homedir [Pathname] Path to GPG home dir
    def initialize(uri, keyring: nil, gpg_homedir: Pathname.new("/root/.gnupg"))
      Yast.import "Linuxrc"
      @uri = uri
      @local_path = nil
      @keyring = keyring
      @gpg_homedir = gpg_homedir
      @signed = nil
    end

    # Determines whether a driver update is signed or not
    #
    # Signature is checked while fetching and extracting the driver update. The reason
    # is that we need to check the original files and we don't want to keep them
    # after the update is extracted (to save some memory during installation).
    #
    # The driver update will be considered signed if the signature is OK and the
    # public key is known. It will be false otherwise. For more details, check
    # #check_gpg_output.
    #
    # @return [Boolean] True if it's correctly signed; false otherwise.
    def signed?
      @signed
    end

    # Fetch the DUD and extract it in the given directory
    #
    # @param target [Pathname] Directory to extract the DUD to.
    def fetch(target)
      @local_path = target
      Dir.mktmpdir do |dir|
        temp_file = Pathname(dir).join(TEMP_FILENAME)
        download_file_to(temp_file)
        clear_attached_signature(temp_file)
        check_detached_signature(temp_file) unless signed?
        extract(temp_file, local_path)
      end
    end

    # Determine if gpg command was successful
    #
    # The signature was successfully signed if command error code was 0 and
    # no warning was shown.
    #
    # @return [Boolean] True if signature check was successful; false otherwise.
    def check_gpg_output(out)
      out["exit"].zero? && !out["stderr"].include?("WARNING")
    end

    # Apply the DUD to inst-sys
    #
    # @see #adddir
    # @see #run_update_pre
    def apply
      raise "Driver updated not fetched yet!" if local_path.nil?
      adddir
      run_update_pre
    end

    private

    # Extract the DUD at 'source' to 'target'
    #
    # @param source [Pathname]
    #
    # @see EXTRACT_CMD
    def extract(source, target)
      cmd = format(EXTRACT_CMD, source: source)
      Dir.chdir(source.dirname) do
        out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
        raise "Could not extract DUD" unless out["exit"].zero?
        setup_target(target)
        ::FileUtils.mv(update_dir, target)
      end
    end

    # Clear and check an attached signature
    #
    # If the file at 'path' is signed, it will extract its content checking its
    # signature. As a side effect, the extracted file will be placed in 'path'.
    #
    # @return [Boolean] True if the package was successfuly signed; false otherwise.
    def clear_attached_signature(path)
      unpacked_path = path.sub_ext(UNPACKED_EXT)
      cmd = format(EXTRACT_SIG_CMD, source: path, unpacked: unpacked_path,
                   keyring: keyring, homedir: gpg_homedir)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      ::FileUtils.mv(unpacked_path, path) if unpacked_path.exist?
      @signed = check_gpg_output(out)
    end

    # Set up the target directory
    #
    # Refresh the target directory (dir will be re-created).
    #
    # @param dir [Pathname] Directory to re-create
    def setup_target(dir)
      ::FileUtils.rm_r(dir) if dir.exist?
      ::FileUtils.mkdir_p(dir.dirname) unless dir.dirname.exist?
    end

    # Download the DUD to a file
    #
    # If the file is not downloaded, DriverUpdate::NotFound exception is risen.
    #
    # @raise DriverUpdate::NotFound
    def download_file_to(path)
      get_file(uri, path)
      raise NotFound unless path.exist?
    end

    # Directory which contains files within the DUD
    #
    # @see UpdateDir value at /etc/install.inf.
    def update_dir
      path = Pathname.new(Yast::Linuxrc.InstallInf("UpdateDir"))
      path.relative_path_from(Pathname.new("/"))
    end

    # Add files/directories to the inst-sys
    #
    # @see APPLY_CMD
    def adddir
      cmd = format(APPLY_CMD, source: local_path)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      raise CouldNotBeApplied unless out["exit"].zero?
    end

    # Run update.pre script
    #
    # @return [Boolean,NilClass] true if execution was successful; false if
    #                            update script didn't exist.
    # @raise DriverUpdate::CouldNotBeApplied
    def run_update_pre
      update_pre_path = local_path.join("install", "update.pre")
      return false unless update_pre_path.exist? && update_pre_path.executable?
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), update_pre_path.to_s)
      raise CouldNotBeApplied unless out["exit"].zero?
      true
    end

    # Wrapper to get a file using Yast::Transfer::FileFromUrl#get_file_from_url
    #
    # @return [Boolean] true if the file was retrieved; false otherwise.
    def get_file(location, path)
      get_file_from_url(scheme: location.scheme, host: location.host, urlpath: location.path,
                        localfile: path.to_s, urltok: {}, destdir: "")
    end

    # Check a detached signature for a DUD
    #
    # The signature will be taken from the same URL than the DUD but adding
    # the suffix '.asc'.
    #
    # @return [Boolean] True if the signature is OK; false otherwise.
    #
    # @see #check_gpg_output
    def check_detached_signature(temp_file)
      # Download the detached signature
      asc_file = temp_file.sub_ext("#{temp_file.extname}#{SIG_EXT}")
      get_file(uri.merge("#{uri}#{SIG_EXT}"), asc_file)

      # Verify the signature
      cmd = format(VERIFY_SIG_CMD, path: asc_file, keyring: keyring, homedir: gpg_homedir)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      ::FileUtils.rm(asc_file) if asc_file.exist?
      @signed = check_gpg_output(out) # Set signature
    end

  end
end

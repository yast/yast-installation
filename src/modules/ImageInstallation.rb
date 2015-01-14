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

# File:
#	ImageInstallation.ycp
#
# Module:
#	ImageInstallation
#
# Summary:
#	Support functions for installation via images
#
# Authors:
#	Jiri Srain <jsrain@suse.cz>
#	Lukas Ocilka <locilka@suse.cz>
#
require "yast"

module Yast
  class ImageInstallationClass < Module
    include Yast::Logger

    IMAGE_COMPRESS_RATIO = 3.6
    MEGABYTE = 2**20

    def main
      Yast.import "UI"
      Yast.import "Pkg"

      Yast.import "Installation"
      Yast.import "XML"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "Arch"
      Yast.import "PackageCallbacks"
      Yast.import "Popup"
      Yast.import "SlideShow"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Packages"
      Yast.import "PackagesUI"

      textdomain "installation"

      # Repository holding all images
      @_repo = nil

      # Description of all available images
      @_images = {}

      # Order of images
      @_image_order = []

      # Image with software management metadata
      @_metadata_image = ""

      # Template for the path for an image on the media
      @_image_path = "/images"

      # List of already mounted images
      @_mounted_images = []

      #
      # **Structure:**
      #
      #     $[
      #        "image_filaname" : $[
      #          // size of an unpacked image in bytes
      #          "size" : integer,
      #          // number of files and directories in an image
      #          "files" : integer,
      #        ]
      #      ]
      @images_details = {}

      # Image currently being deployed
      @_current_image = {}

      # display progress messages every NUMBERth record
      @_checkpoint = 400

      # NUMBER of bytes per record, multiple of 512
      @_record_size = 10_240

      @last_patterns_selected = []

      @changed_by_user = false

      # Defines whether some installation images are available
      @image_installation_available = nil

      @debug_mode = nil

      @tar_image_progress = nil

      @download_image_progress = nil

      @start_download_handler = nil

      @generic_set_progress = nil

      @_current_image_from_imageset = -1

      # --> Storing and restoring states

      # List of all handled types.
      # list <symbol> all_supported_types = [`product, `pattern, `language, `package, `patch];
      # Zypp currently counts [ `product, `pattern, `language ]
      @all_supported_types = [:package, :patch]

      # Map that stores all the requested states of all handled/supported types.
      @objects_state = {}

      @progress_layout = {
        "storing_user_prefs"   => {
          "steps_start_at" => 0,
          "steps_reserved" => 6
        },
        "deploying_images"     => {
          "steps_start_at" => 6,
          "steps_reserved" => 84
        },
        "restoring_user_prefs" => {
          "steps_start_at" => 90,
          "steps_reserved" => 10
        }
      }

      # Images selected by FindImageSet()
      @selected_images = {}
    end

    # Set the repository to get images from
    # @param [Fixnum] repo integer the repository identification
    def SetRepo(repo)
      @_repo = repo
      Builtins.y2milestone("New images repo: %1", @_repo)

      nil
    end

    # Adjusts the repository for images
    def InitRepo
      return if !@_repo.nil?

      SetRepo(Ops.get(Packages.theSources, 0, 0))

      nil
    end

    def ThisIsADebugMode
      if @debug_mode.nil?
        @debug_mode = ProductFeatures.GetBooleanFeature(
          "globals",
          "debug_deploying"
        ) == true
        Builtins.y2milestone("ImageInstallation debug mode: %1", @debug_mode)
      end

      @debug_mode
    end

    # Order of images to be deployed
    # @return a list of images definint the order
    def ImageOrder
      deep_copy(@_image_order)
    end

    # Returns list of currently selected images.
    #
    # @return [Hash <String,Hash{String => Object>}] images
    # @see #AddImage
    #
    #
    # **Structure:**
    #
    #     $[
    #        "image_id":$[
    #          "file":filename,
    #          "type":type
    #        ], ...
    #      ]
    def GetCurrentImages
      deep_copy(@_images)
    end

    # Add information about new image
    # @param [String] name string the name/id of the image
    # @param [String] file string the file name of the image
    # @param [String] type string the type of the image, one of "tar" and "fs"
    def AddImage(name, file, type)
      Ops.set(
        @_images,
        file,
        "file" => file, "type" => type, "name" => name
      )

      nil
    end

    # Removes the downloaded image. If the file is writable, releases
    # all sources because only libzypp knows which files are copies
    # and which are just symlinks to sources (e.g., nfs://, smb://).
    def RemoveTemporaryImage(image)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "test -w '%1' && echo -n writable",
            String.Quote(image)
          )
        )
      )

      # Command has either failed or file is writable (non-empty stdout)
      if Ops.get_integer(out, "exit", -1) != 0 ||
          Ops.get_string(out, "stdout", "") != ""
        Builtins.y2milestone("Releasing sources to remove temporary files")
        Pkg.SourceReleaseAll
      end

      nil
    end

    def SetDeployTarImageProgress(tip)
      tip = deep_copy(tip)
      @tar_image_progress = deep_copy(tip)
      Builtins.y2milestone("New tar_image_progress: %1", @tar_image_progress)

      nil
    end

    def SetDownloadTarImageProgress(tip)
      tip = deep_copy(tip)
      @download_image_progress = deep_copy(tip)
      Builtins.y2milestone(
        "New download_image_progress: %1",
        @download_image_progress
      )

      nil
    end

    # BNC #449792
    def SetStartDownloadImageProgress(sdi)
      sdi = deep_copy(sdi)
      @start_download_handler = deep_copy(sdi)
      Builtins.y2milestone(
        "New start_download_handler: %1",
        @start_download_handler
      )

      nil
    end

    def SetOverallDeployingProgress(odp)
      odp = deep_copy(odp)
      @generic_set_progress = deep_copy(odp)
      Builtins.y2milestone(
        "New generic_set_progress: %1",
        @generic_set_progress
      )

      nil
    end

    # Deploy an image of the filesystem type
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to
    # @return [Boolean] true on success
    def DeployTarImage(id, target)
      InitRepo()

      file = Ops.get_string(@_images, [id, "file"], "")
      Builtins.y2milestone("Untarring image %1 (%2) to %3", id, file, target)
      file = Builtins.sformat("%1/%2", @_image_path, file)
      # BNC #409927
      # Checking files for signatures
      image = Pkg.SourceProvideDigestedFile(@_repo, 1, file, false)

      if image.nil?
        Builtins.y2error("File %1 not found on media", file)
        return false
      end

      # reset, adjust labels, etc.
      @tar_image_progress.call(0) if !@tar_image_progress.nil?

      Builtins.y2milestone("Creating target directory")
      cmd = Builtins.sformat("test -d %1 || mkdir -p %1", target)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      if Ops.get_integer(out, "exit", -1) != 0
        Builtins.y2error("no directory to extract into, aborting")
        return false
      end

      Builtins.y2milestone("Untarring the image")

      # lzma
      if Builtins.regexpmatch(image, ".lzma$")
        cmd = Builtins.sformat(
          "lzmadec < '%1' | tar --numeric-owner --totals --checkpoint=%3 --record-size=%4 -C '%2' -xf -",
          String.Quote(image),
          String.Quote(target),
          @_checkpoint,
          @_record_size
        )
        # xzdec
        # BNC #476079
      elsif Builtins.regexpmatch(image, ".xz$")
        cmd = Builtins.sformat(
          "xzdec < '%1' | tar --numeric-owner --totals --checkpoint=%3 --record-size=%4 -C '%2' -xf -",
          String.Quote(image),
          String.Quote(target),
          @_checkpoint,
          @_record_size
        )
        # bzip2, gzip
      else
        cmd = Builtins.sformat(
          "tar --numeric-owner --checkpoint=%3 --record-size=%4 --totals -C '%2' -xf '%1'",
          String.Quote(image),
          String.Quote(target),
          @_checkpoint,
          @_record_size
        )
      end
      Builtins.y2milestone("Calling: %1", cmd)

      pid = Convert.to_integer(SCR.Execute(path(".process.start_shell"), cmd))

      read_checkpoint_str = "^tar: Read checkpoint ([0123456789]+)$"

      # Otherwise it will never make 100%
      better_feeling_constant = @_checkpoint

      ret = nil
      aborted = false

      while SCR.Read(path(".process.running"), pid) == true
        newline = Convert.to_string(
          SCR.Read(path(".process.read_line_stderr"), pid)
        )

        if !newline.nil?
          if !Builtins.regexpmatch(newline, read_checkpoint_str)
            Builtins.y2milestone("Deploying image: %1", newline)
            next
          end

          newline = Builtins.regexpsub(newline, read_checkpoint_str, "\\1")

          next if newline.nil? || newline == ""

          if !@tar_image_progress.nil?
            @tar_image_progress.call(
              Ops.add(Builtins.tointeger(newline), better_feeling_constant)
            )
          end
        else
          ret = UI.PollInput
          if ret == :abort || ret == :cancel
            if Popup.ConfirmAbort(:unusable)
              Builtins.y2warning("Aborted!")
              aborted = true
              break
            end
          else
            SlideShow.HandleInput(ret)
            Builtins.sleep(200)
          end
        end
      end

      # BNC #456337
      # Checking the exit code (0 = OK, nil = still running, 'else' = error)
      exitcode = Convert.to_integer(SCR.Read(path(".process.status"), pid))

      if !exitcode.nil? && exitcode != 0
        Builtins.y2milestone(
          "Deploying has failed, exit code was: %1, stderr: %2",
          exitcode,
          SCR.Read(path(".process.read_stderr"), pid)
        )
        aborted = true
      end

      Builtins.y2milestone("Finished")

      return false if aborted

      # adjust labels etc.
      @tar_image_progress.call(100) if !@tar_image_progress.nil?

      RemoveTemporaryImage(image)

      true
    end

    # Deploy an image of the filesystem type
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to
    # @return [Boolean] true on success
    def DeployFsImage(id, target)
      InitRepo()

      file = Ops.get_string(@_images, [id, "file"], "")
      Builtins.y2milestone("Deploying FS image %1 (%2) on %3", id, file, target)
      file = Builtins.sformat("%1/%2", @_image_path, file)
      # BNC #409927
      # Checking files for signatures
      image = Pkg.SourceProvideDigestedFile(@_repo, 1, file, false)

      if image.nil?
        Builtins.y2error("File %1 not found on media", file)
        return false
      end

      Builtins.y2milestone("Creating temporary directory")
      tmpdir = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        Builtins.sformat("/images/%1", id)
      )
      cmd = Builtins.sformat("test -d %1 || mkdir -p %1", tmpdir)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      Builtins.y2milestone("Mounting the image")
      cmd = Builtins.sformat("mount -o noatime,loop %1 %2", image, tmpdir)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      Builtins.y2milestone("Creating target directory")
      cmd = Builtins.sformat("test -d %1 || mkdir -p %1", target)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      Builtins.y2milestone("Copying contents of the image")
      cmd = Builtins.sformat("cp -a %1/* %2", tmpdir, target)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      Builtins.y2milestone("Unmounting image from temporary directory")
      cmd = Builtins.sformat("umount -d -f -l %1", tmpdir)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      RemoveTemporaryImage(image)

      Ops.get_integer(out, "exit", -1) == 0
      # FIXME: error checking
    end

    def DeployDiskImage(id, target)
      InitRepo()

      file = Ops.get_string(@_images, [id, "file"], "")
      Builtins.y2milestone("Deploying disk image %1 (%2) on %3", id, file, target)
      file = Builtins.sformat("%1/%2", @_image_path, file)
      # BNC #409927
      # Checking files for signatures
      image = Pkg.SourceProvideDigestedFile(@_repo, 1, file, false)

      if image.nil?
        Builtins.y2error("File %1 not found on media", file)
        return false
      end

      Builtins.y2milestone("Copying the image")
      cmd = Builtins.sformat("dd bs=1048576 if=%1 of=%2", image, target) # 1MB of block size
      out = SCR.Execute(path(".target.bash_output"), cmd)
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)

      RemoveTemporaryImage(image)

      out["exit"] == 0
    end

    # Mount an image of the filesystem type
    # Does not integrate to the system, mounts on target
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to
    # @return [Boolean] true on success
    def MountFsImage(id, target)
      InitRepo()

      file = Ops.get_string(@_images, [id, "file"], "")
      Builtins.y2milestone("Mounting image %1 (%2) on %3", id, file, target)
      file = Builtins.sformat("%1/%2", @_image_path, file)
      # BNC #409927
      # Checking files for signatures
      image = Pkg.SourceProvideDigestedFile(@_repo, 1, file, false)

      if image.nil?
        Builtins.y2error("File %1 not found on media", file)
        return false
      end
      cmd = Builtins.sformat("test -d %1 || mkdir -p %1", target)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)
      cmd = Builtins.sformat("mount -o noatime,loop %1 %2", image, target)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Executing %1 returned %2", cmd, out)
      Ops.get_integer(out, "exit", -1) == 0
      # FIXME: error checking
      # FIXME: unmounting
    end

    def TotalSize
      sum = 0

      Builtins.y2milestone(
        "Computing total images size from [%1], data %2",
        @_image_order,
        @images_details
      )
      Builtins.foreach(@_image_order) do |image|
        # 128 MB as a fallback size
        # otherwise progress would not move at all
        sum = Ops.add(sum, Ops.get(@images_details, [image, "size"], 134_217_728))
      end

      Builtins.y2milestone("Total images size: %1", sum)
      sum
    end

    def SetCurrentImageDetails(img)
      img = deep_copy(img)
      @_current_image_from_imageset = Ops.add(@_current_image_from_imageset, 1)

      if Builtins.size(@images_details) == 0
        Builtins.y2warning("Images details are empty")
      end

      @_current_image = {
        "file"         => Ops.get_string(img, "file", ""),
        "name"         => Ops.get_string(img, "name", ""),
        "size"         => Ops.get(
          @images_details,
          [Ops.get_string(img, "file", ""), "size"],
          0
        ),
        "files"        => Ops.get(
          @images_details,
          [Ops.get_string(img, "file", ""), "files"],
          0
        ),
        # 100% progress
        "max_progress" => Builtins.tointeger(
          Ops.divide(
            Ops.get(
              @images_details,
              [Ops.get_string(img, "file", ""), "size"],
              0
            ),
            @_record_size
          )
        ),
        "image_nr"     => @_current_image_from_imageset
      }

      nil
    end

    def GetCurrentImageDetails
      deep_copy(@_current_image)
    end

    # Deploy an image (internal implementation)
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to
    # @param [Boolean] temporary boolean true to only mount if possible (no copy)
    # @return [Boolean] true on success
    def _DeployImage(id, target, temporary)
      img = Ops.get(@_images, id, {})
      Builtins.y2error("Image %1 does not exist", id) if img == {}

      type = Ops.get_string(img, "type", "")

      SetCurrentImageDetails(img)

      if type == "fs"
        return temporary ? MountFsImage(id, target) : DeployFsImage(id, target)
      elsif type == "tar"
        return DeployTarImage(id, target)
      elsif type == "raw"
        return DeployDiskImage(id, target)
      end

      Builtins.y2error("Unknown type of image: %1", type)
      false
    end

    # Deploy an image
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to
    # @return [Boolean] true on success
    def DeployImage(id, target)
      Builtins.y2milestone("Deploying image %1 to %2", id, target)
      _DeployImage(id, target, false)
    end

    # Deploy an image temporarily (just mount if possible)
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to,
    # @return [Boolean] true on success
    def DeployImageTemporarily(id, target)
      Builtins.y2milestone("Temporarily delploying image %1 to %2", id, target)
      _DeployImage(id, target, true)
    end

    # UnDeploy an image temporarily (if possible, only for the FS images)
    # @param [String] id string the id of the image
    # @param [String] target string the directory to deploy the image to,
    # @return [Boolean] true on success
    def CleanTemporaryImage(id, target)
      Builtins.y2milestone(
        "UnDelploying temporary image %1 from %2",
        id,
        target
      )
      if Ops.get_string(@_images, [id, "type"], "") == "fs"
        cmd = Builtins.sformat("umount %1", target)
        out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("Executing %1 returned %2", cmd, out)
        return Ops.get_integer(out, "exit", -1) == 0
      end
      Builtins.y2milestone(
        "Cannot undeploy image of type %1",
        Ops.get_string(@_images, [id, "type"], "")
      )
      true
    end

    # Loads non-mandatory details for every single selected image.
    def FillUpImagesDetails
      InitRepo()

      # bnc #439104
      if @_repo.nil?
        Builtins.y2warning("No images-repository defined")
        return true
      end

      # ppc (covers also ppc64), i386, x86_64 ...
      filename = nil

      possible_files = [
        Builtins.sformat("%1/details-%2.xml", @_image_path, Arch.arch_short),
        Builtins.sformat("%1/details.xml", @_image_path)
      ]

      Builtins.foreach(possible_files) do |try_file|
        # BNC #409927
        # Checking files for signatures
        filename = Pkg.SourceProvideDigestedFile(@_repo, 1, try_file, true)
        if !filename.nil? && filename != ""
          Builtins.y2milestone(
            "Using details file: %1 (%2)",
            filename,
            try_file
          )
          raise Break
        end
      end

      if filename.nil?
        Builtins.y2milestone("No image installation details found")
        return false
      end

      read_details = XML.XMLToYCPFile(filename)
      if read_details.nil?
        Builtins.y2error("Cannot parse imagesets details")
        return false
      end

      if !Builtins.haskey(read_details, "details")
        Builtins.y2warning("No images details in details.xml")
        return false
      end

      @images_details = {}

      Builtins.foreach(Ops.get_list(read_details, "details", [])) do |image_detail|
        file = Ops.get_string(image_detail, "file", "")
        next if file.nil? || file == ""
        files = Builtins.tointeger(Ops.get_string(image_detail, "files", "0"))
        isize = Builtins.tointeger(Ops.get_string(image_detail, "size", "0"))
        Ops.set(@images_details, file,  "files" => files, "size" => isize)
      end

      # FIXME: y2debug
      Builtins.y2milestone("Details: %1", @images_details)
      true
    end

    # Deploy all images
    # @param [Array<String>] images a list of images to deploy
    # @param [String] target string directory where to deploy the images
    # @param [void (integer, integer)] progress a function to report overal progress
    def DeployImages(images, target, progress)
      images = deep_copy(images)
      progress = deep_copy(progress)
      # unregister callbacks
      PackageCallbacks.RegisterEmptyProgressCallbacks

      # downloads details*.xml file
      FillUpImagesDetails()

      # register own callback for downloading
      if !@download_image_progress.nil?
        Pkg.CallbackProgressDownload(@download_image_progress)
      end

      # register own callback for start downloading
      if !@start_download_handler.nil?
        Pkg.CallbackStartDownload(@start_download_handler)
      end

      num = -1
      @_current_image_from_imageset = -1
      aborted = nil

      Builtins.foreach(images) do |img|
        num = Ops.add(num, 1)
        progress.call(num, 0) if !progress.nil?
        if !DeployImage(img, target)
          aborted = true
          Builtins.y2milestone("Aborting...")
          raise Break
        end
        progress.call(num, 100) if !progress.nil?
      end

      return nil if aborted == true

      # unregister downloading progress
      Pkg.CallbackProgressDownload(nil) if !@download_image_progress.nil?

      # reregister callbacks
      PackageCallbacks.RestorePreviousProgressCallbacks

      true
      # TODO: error checking
    end

    # Returns the intersection of both patterns supported by the imageset
    # and patterns going to be installed.
    def CountMatchingPatterns(imageset_patterns, installed_patterns)
      imageset_patterns = deep_copy(imageset_patterns)
      installed_patterns = deep_copy(installed_patterns)
      ret = 0

      Builtins.foreach(installed_patterns) do |one_installed_pattern|
        if Builtins.contains(imageset_patterns, one_installed_pattern)
          ret = Ops.add(ret, 1)
        end
      end

      ret
    end

    def EnoughPatternsMatching(matching_patterns, patterns_in_imagesets)
      if matching_patterns.nil? || Ops.less_than(matching_patterns, 0)
        return false
      end

      if patterns_in_imagesets.nil? || Ops.less_than(patterns_in_imagesets, 0)
        return false
      end

      # it's actually matching_patterns = patterns_in_imagesets
      Ops.greater_or_equal(matching_patterns, patterns_in_imagesets)
    end

    def PrepareOEMImage(path)
      AddImage(
        "OEM", path, "raw"
      )
      @_image_order = [path]
    end

    # Find a set of images which suites selected patterns
    # @param [Array<String>] patterns a list of patterns which are selected
    # @return [Boolean] true on success or when media does not contain any images
    def FindImageSet(patterns)
      patterns = deep_copy(patterns)
      InitRepo()

      # reset all data
      @_images = {}
      @_image_order = []
      @_metadata_image = ""

      # checking whether images are supported
      # BNC #409927
      # Checking files for signatures
      filename = Pkg.SourceProvideDigestedFile(
        @_repo,
        1,
        Builtins.sformat("%1/images.xml", @_image_path),
        false
      )

      if filename.nil?
        @image_installation_available = false
        Installation.image_installation = false
        Installation.image_only = false
        Builtins.y2milestone("Image list for installation not found")
        return true
      end

      image_descr = XML.XMLToYCPFile(filename)
      if image_descr.nil?
        @image_installation_available = false
        Installation.image_installation = false
        Installation.image_only = false
        Report.Error(_("Failed to read information about installation images"))
        return false
      end

      # images are supported
      # bnc #492745: Do not offer images if there are none
      @image_installation_available = true

      image_sets = Ops.get_list(image_descr, "image_sets", [])
      Builtins.y2debug("Image set descriptions: %1", image_sets)
      result = {}

      # more patterns could match at once
      # as we can't merge the meta image, only one can be selected
      possible_patterns = {}
      matching_patterns = {}
      patterns_in_imagesets = {}

      # ppc (covers also ppc64), i386, x86_64 ...
      arch_short = Arch.arch_short
      Builtins.y2milestone("Current architecture is: %1", arch_short)

      # filter out imagesets for another architecture
      image_sets = Builtins.filter(image_sets) do |image|
        imageset_archs = Builtins.splitstring(
          Ops.get_string(image, "archs", ""),
          " ,"
        )
        # no architecture defined == noarch
        if Builtins.size(imageset_archs) == 0
          next true
          # does architecture match?
        else
          if Builtins.contains(imageset_archs, arch_short)
            next true
          else
            # For debugging purpose
            Builtins.y2milestone(
              "Filtered-out, Patterns: %1, Archs: %2",
              Ops.get_string(image, "patterns", ""),
              Ops.get_string(image, "archs", "")
            )
            next false
          end
        end
      end

      # trying to find all matching patterns
      Builtins.foreach(image_sets) do |image|
        pattern = image["patterns"]
        imageset_patterns = Builtins.splitstring(pattern, ", ")
        Ops.set(
          patterns_in_imagesets,
          pattern,
          Builtins.size(imageset_patterns)
        )
        # no image-pattern defined, matches all patterns
        if Builtins.size(imageset_patterns) == 0
          Ops.set(possible_patterns, pattern, image)
          # image-patterns matches to patterns got as parameter
        else
          Ops.set(
            matching_patterns,
            pattern,
            CountMatchingPatterns(imageset_patterns, patterns)
          )

          if Ops.greater_than(Ops.get(matching_patterns, pattern, 0), 0)
            Ops.set(possible_patterns, pattern, image)
          else
            # For debugging purpose
            Builtins.y2milestone(
              "Filtered-out, Patterns: %1, Matching: %2",
              Ops.get_string(image, "patterns", ""),
              Ops.get(matching_patterns, pattern, -1)
            )
          end
        end
      end

      log.info "Matching patterns: #{possible_patterns}, sizes: #{matching_patterns}"

      # selecting the best imageset
      last_pattern = ""

      if Ops.greater_than(Builtins.size(possible_patterns), 0)
        last_number_of_matching_patterns = -1
        last_pattern = ""

        Builtins.foreach(possible_patterns) do |pattern, image|
          if Ops.greater_than(
            Ops.get(
              # imageset matches more patterns than the currently best-one
              matching_patterns,
              pattern,
              0
            ),
            last_number_of_matching_patterns
            ) &&
              # enough patterns matches the selected imageset
              EnoughPatternsMatching(
                Ops.get(matching_patterns, pattern, 0),
                Ops.get(patterns_in_imagesets, pattern, 0)
              )
            last_number_of_matching_patterns = Ops.get(
              matching_patterns,
              pattern,
              0
            )
            result = deep_copy(image)
            last_pattern = pattern
          end
        end
      end

      Builtins.y2milestone("Result: %1/%2", last_pattern, result)
      @selected_images = result

      # No matching pattern
      if result == {}
        Installation.image_installation = false
        Installation.image_only = false
        Builtins.y2milestone("No image for installation found")
        return true
      end

      # We've selected one
      Installation.image_installation = true

      if Builtins.haskey(result, "pkg_image")
        @_metadata_image = Ops.get_string(result, "pkg_image", "")
      else
        Installation.image_only = true
      end

      # Adding images one by one into the pool
      Builtins.foreach(Ops.get_list(result, "images", [])) do |img|
        # image must have unique <file>...</file> defined
        if Ops.get(img, "file", "") == ""
          Builtins.y2error("No file defined for %1", img)
          next
        end
        @_image_order = Builtins.add(@_image_order, Ops.get(img, "file", ""))
        AddImage(
          Ops.get(img, "name", ""),
          Ops.get(img, "file", ""),
          Ops.get(img, "type", "")
        )
      end

      Builtins.y2milestone(
        "Image-only installation: %1",
        Installation.image_only
      )
      Builtins.y2milestone("Images: %1", @_images)
      Builtins.y2milestone("Image installation order: %1", @_image_order)

      if !Installation.image_only
        Builtins.y2milestone(
          "Image with software management metadata: %1",
          @_metadata_image
        )
      end

      true
    end

    # Returns map with description which images will be used
    #
    # @return [Hash] with description
    #
    #
    # **Structure:**
    #
    #     $[
    #        "deploying_enabled" : boolean,
    #        "images" : returned by GetCurrentImages()
    #      ]
    #
    # @see #GetCurrentImages()
    def ImagesToUse
      ret = {}

      if Installation.image_installation == true
        ret = { "deploying_enabled" => true, "images" => GetCurrentImages() }
      else
        Ops.set(ret, "deploying_enabled", false)
      end

      deep_copy(ret)
    end

    def calculate_fs_size(mountpoint)
      cmd = Builtins.sformat("df -P -k %1", mountpoint)
      Builtins.y2milestone("Executing %1", cmd)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Output: %1", out)
      total_str = Ops.get_string(out, "stdout", "")
      total_str = Ops.get(Builtins.splitstring(total_str, "\n"), 1, "")
      return Ops.divide(
        Builtins.tointeger(
          Ops.get(Builtins.filter(Builtins.splitstring(total_str, " ")) do |s|
            s != ""
          end, 2, "0")
        ),
        1024
      )
    end

    # Copy a subtree, limit to a single filesystem
    # @param [String] from string source directory
    # @param [String] to string target directory
    # @return [Boolean] true on success
    def FileSystemCopy(from, to, progress_start, progress_finish)
      if from == "/"
        # root is a merge of two filesystems, df returns only one part for /
        total_mb = calculate_fs_size("/read-write") + calculate_fs_size("/read-only")
      else
        total_mb = 0
      end
      total_mb = calculate_fs_size(from) if total_mb == 0
      # Using df-based progress estimation, is rather faster
      #    may be less precise
      #    see bnc#555288
      #     string cmd = sformat ("du -x -B 1048576 -s %1", from);
      #     y2milestone ("Executing %1", cmd);
      #     map out = (map)SCR::Execute (.target.bash_output, cmd);
      #     y2milestone ("Output: %1", out);
      #     string total_str = out["stdout"]:"";
      #     integer total_mb = tointeger (total_str);
      total_mb = (total_mb * IMAGE_COMPRESS_RATIO).to_i # compression ratio - rough estimate
      total_mb = 4096 if total_mb == 0 # should be big enough

      tmp_pipe1 = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/system_clone_fifo_1"
      )
      tmp_pipe2 = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/system_clone_fifo_2"
      )
      # FIXME: this does not copy pipes in filesystem (usually not an issue)
      cmd = Builtins.sformat(
        "mkfifo %3 ;\n" \
          "\t mkfifo %4 ;\n" \
          "\t tar -C %1 --hard-dereference --numeric-owner -cSf %3 --one-file-system . &\n" \
          "\t dd bs=1048576 if=%3 of=%4 >&2 &\n" \
          "\t jobs -l >&2;\n" \
          "\t tar -C %2 --numeric-owner -xSf %4",
        from,
        to,
        tmp_pipe1,
        tmp_pipe2
      )
      Builtins.y2milestone("Executing %1", cmd)
      process = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), cmd, {})
      )
      pid = ""

      while Convert.to_boolean(SCR.Read(path(".process.running"), process))
        done = nil
        line = Convert.to_string(
          SCR.Read(path(".process.read_line_stderr"), process)
        )
        until line.nil?
          if pid == ""
            if !Builtins.regexpmatch(
              line,
              Builtins.sformat(
                "dd bs=1048576 if=%1 of=%2",
                tmp_pipe1,
                tmp_pipe2
              )
              )
              pid = ""
            else
              pid = Builtins.regexpsub(line, "([0-9]+) [^ 0-9]+ +dd", "\\1")
              Builtins.y2milestone("DD's pid: %1", pid)
              # sleep in order not to kill -USR1 to dd too early, otherwise it finishes
              Builtins.sleep(5000)
            end
          elsif Builtins.regexpmatch(line, "^[0-9]+ ")
            done = Builtins.regexpsub(line, "^([0-9]+) ", "\\1")
          end
          Builtins.y2debug("Done: %1", done)
          line = Convert.to_string(
            SCR.Read(path(".process.read_line_stderr"), process)
          )
        end
        if pid != ""
          cmd = Builtins.sformat("/bin/kill -USR1 %1", pid)
          Builtins.y2debug("Executing %1", cmd)
          SCR.Execute(path(".target.bash"), cmd)
        end
        Builtins.sleep(300)
        next if done.nil?

        progress = Ops.add(
          progress_start,
          Ops.divide(
            Ops.divide(
              Ops.divide(
                Ops.multiply(
                  Ops.subtract(progress_finish, progress_start),
                  Builtins.tointeger(done) / MEGABYTE # count megabytes
                ),
                total_mb
              ),
              1024
            ),
            1024
          )
        )
        Builtins.y2debug("Setting progress to %1", progress)
        SlideShow.StageProgress(progress, nil)
        SlideShow.SubProgress(
          Ops.divide(
            Ops.divide(
              Ops.divide(
                Ops.multiply(
                  Ops.subtract(progress_finish, progress_start),
                  Builtins.tointeger(done)
                ),
                total_mb
              ),
              1024
            ),
            1024
          ),
          nil
        )
      end

      copy_result = Convert.to_integer(
        SCR.Read(path(".process.status"), process)
      )
      Builtins.y2milestone("Result: %1", copy_result)
      SCR.Execute(path(".target.remove"), tmp_pipe1)
      SCR.Execute(path(".target.remove"), tmp_pipe2)
      cmd = Builtins.sformat(
        "chown --reference=%1 %2; chmod --reference=%1 %2",
        from,
        to
      )
      Builtins.y2milestone("Executing %1", cmd)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Result: %1", out)
      Ops.get_integer(out, "exit", -1) == 0 && copy_result == 0
    end

    def GetProgressLayoutDetails(id, details)
      Ops.get_integer(@progress_layout, [id, details], 0)
    end

    def GetProgressLayoutLabel(id)
      Ops.get_locale(@progress_layout, [id, "label"], _("Deploying..."))
    end

    def AdjustProgressLayout(id, steps_total, label)
      if !Builtins.haskey(@progress_layout, id)
        Builtins.y2error("Unknown key: %1", id)
        return
      end

      Ops.set(@progress_layout, [id, "label"], label)
      Ops.set(@progress_layout, [id, "steps_total"], steps_total)

      nil
    end

    # Function stores all new/requested states of all handled/supported types.
    #
    # @see #all_supported_types
    # @see #objects_state
    def StoreAllChanges
      nr_steps = Ops.multiply(4, Builtins.size(@all_supported_types))
      id = "storing_user_prefs"

      AdjustProgressLayout(id, nr_steps, _("Storing user preferences..."))

      @generic_set_progress.call(id, 0) if !@generic_set_progress.nil?

      # Query for changed state of all knwon types
      # 'changed' means that they were 'installed' and 'not locked' before
      Builtins.foreach(@all_supported_types) do |one_type|
        # list of $[ "name":string, "version":string, "arch":string, "source":integer, "status":symbol, "locked":boolean ]
        # status is `installed, `removed, `selected or `available, source is source ID or -1 if the resolvable is installed in the target
        # if status is `available and locked is true then the object is set to taboo
        # if status is `installed and locked is true then the object locked
        resolvable_properties = Pkg.ResolvableProperties("", one_type, "")
        # FIXME: Store only those keys we need (arch, name, version?)
        Ops.set(@objects_state, one_type, {})
        remove_resolvables = Builtins.filter(resolvable_properties) do |one_object|
          Ops.get_symbol(one_object, "status", :unknown) == :removed
        end
        Ops.set(@objects_state, [one_type, "remove"], remove_resolvables)
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        install_resolvables = Builtins.filter(resolvable_properties) do |one_object|
          Ops.get_symbol(one_object, "status", :unknown) == :selected
        end
        Ops.set(@objects_state, [one_type, "install"], install_resolvables)
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        taboo_resolvables = Builtins.filter(resolvable_properties) do |one_object|
          Ops.get_symbol(one_object, "status", :unknown) == :available &&
            Ops.get_boolean(one_object, "locked", false) == true
        end
        Ops.set(@objects_state, [one_type, "taboo"], taboo_resolvables)
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        lock_resolvables = Builtins.filter(resolvable_properties) do |one_object|
          Ops.get_symbol(one_object, "status", :unknown) == :installed &&
            Ops.get_boolean(one_object, "locked", false) == true
        end
        Ops.set(@objects_state, [one_type, "lock"], lock_resolvables)
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
      end

      if ThisIsADebugMode()
        # map <symbol, map <string, list <map> > > objects_state = $[];
        Builtins.foreach(@objects_state) do |object_type, objects_status|
          Builtins.foreach(objects_status) do |one_status, list_of_objects|
            Builtins.y2milestone(
              "Object type: %1, New status: %2, List of objects: %3",
              object_type,
              one_status,
              list_of_objects
            )
          end
        end
      end

      nil
    end

    # @return [Boolean] whether the package should be additionally installed
    def ProceedWithSelected(one_object, one_type)
      # This package has been selected to be installed

      arch = Ops.get_string(one_object.value, "arch", "")
      # Query for all packages of the same version
      resolvable_properties = Pkg.ResolvableProperties(
        Ops.get_string(one_object.value, "name", "-x-"),
        one_type.value,
        Ops.get_string(one_object.value, "version", "-x-")
      )

      if ThisIsADebugMode()
        Builtins.y2milestone(
          "Looking for %1 returned %2",
          one_object.value,
          resolvable_properties
        )
      end

      # Leave only already installed (and matching the same architecture)
      resolvable_properties = Builtins.filter(resolvable_properties) do |one_resolvable|
        Ops.get_symbol(one_resolvable, "status", :unknown) == :installed &&
          Ops.get_string(one_resolvable, "arch", "") == arch
      end

      if ThisIsADebugMode()
        Builtins.y2milestone("Resolvables installed: %1", resolvable_properties)
      end

      ret = nil

      # There are some installed (matching the same arch, version, and name)
      if Ops.greater_than(Builtins.size(resolvable_properties), 0)
        Builtins.y2milestone(
          "Resolvable type: %1, name: %2 already installed",
          one_type.value,
          Ops.get_string(one_object.value, "name", "-x-")
        )
        # Let's keep the installed version
        Pkg.ResolvableNeutral(
          Ops.get_string(one_object.value, "name", "-x-"),
          one_type.value,
          true
        )
        # is already installed
        ret = false
        # They are not installed
      else
        Builtins.y2milestone(
          "Installing type: %1, details: %2,%3,%4",
          one_type.value,
          Ops.get_string(one_object.value, "name", ""),
          Ops.get_string(one_object.value, "arch", ""),
          Ops.get_string(one_object.value, "version", "")
        )
        # Confirm we want to install them (they might have been added as dependencies)
        Pkg.ResolvableInstallArchVersion(
          Ops.get_string(one_object.value, "name", ""),
          one_type.value,
          Ops.get_string(one_object.value, "arch", ""),
          Ops.get_string(one_object.value, "version", "")
        )
        # should be installed
        ret = true
      end

      ret
    end

    # Restores packages statuses from 'objects_state': Selects packages for removal, installation, upgrade.
    #
    # @return [Boolean] if successful
    def RestoreAllChanges
      nr_steps = Ops.multiply(4, Builtins.size(@all_supported_types))
      id = "restoring_user_prefs"

      AdjustProgressLayout(id, nr_steps, _("Restoring user preferences..."))

      @generic_set_progress.call(id, 0) if !@generic_set_progress.nil?

      Builtins.foreach(@all_supported_types) do |one_type|
        resolvable_properties = Pkg.ResolvableProperties("", one_type, "")
        # All packages selected for installation
        # both `to-install and `to-upgrade (already) installed
        to_install = Builtins.filter(resolvable_properties) do |one_resolvable|
          Ops.get_symbol(one_resolvable, "status", :unknown) == :selected
        end
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        # List of all packages selected for installation (just names)
        selected_for_installation_pkgnames = Builtins.maplist(
          Ops.get(@objects_state, [one_type, "install"], [])
        ) do |one_resolvable|
          Ops.get_string(one_resolvable, "name", "")
        end
        # All packages selected to be installed
        # [ $[ "arch" : ... , "name" : ... , "version" : ... ], ... ]
        selected_for_installation = Builtins.maplist(
          Ops.get(@objects_state, [one_type, "install"], [])
        ) do |one_resolvable|
          {
            "arch"    => Ops.get_string(one_resolvable, "arch", ""),
            "name"    => Ops.get_string(one_resolvable, "name", ""),
            "version" => Ops.get_string(one_resolvable, "version", "")
          }
        end
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        # Delete all packages that are installed but should not be
        one_already_installed_resolvable = {}
        Builtins.foreach(resolvable_properties) do |one_resolvable|
          # We are interested in the already installed resolvables only
          if Ops.get_symbol(one_resolvable, "status", :unknown) != :installed &&
              Ops.get_symbol(one_resolvable, "status", :unknown) != :selected
            next
          end
          one_already_installed_resolvable = {
            "arch"    => Ops.get_string(one_resolvable, "arch", ""),
            "name"    => Ops.get_string(one_resolvable, "name", ""),
            "version" => Ops.get_string(one_resolvable, "version", "")
          }
          # Already installed resolvable but not in list of resolvables to be installed
          if !Builtins.contains(
            selected_for_installation,
            one_already_installed_resolvable
            )
            # BNC #489448: Do not remove package which is installed in different version and/or arch
            # It will be upgraded later
            if Builtins.contains(
              selected_for_installation_pkgnames,
              Ops.get_string(one_resolvable, "name", "-x-")
              )
              Builtins.y2milestone(
                "Not Removing type: %1, name: %2 version: %3",
                one_type,
                Ops.get_string(one_resolvable, "name", "-x-"),
                Ops.get_string(one_resolvable, "version", "-x-")
              )
              # Package is installed or selected but should not be, remove it
            else
              Builtins.y2milestone(
                "Removing type: %1, name: %2 version: %3",
                one_type,
                Ops.get_string(one_resolvable, "name", "-x-"),
                Ops.get_string(one_resolvable, "version", "-x-")
              )
              Pkg.ResolvableRemove(
                Ops.get_string(one_resolvable, "name", "-x-"),
                one_type
              )
            end
          end
        end
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
        # Install all packages that aren't yet
        Builtins.foreach(to_install) do |one_to_install|
          one_to_install_ref = arg_ref(one_to_install)
          one_type_ref = arg_ref(one_type)
          ProceedWithSelected(one_to_install_ref, one_type_ref)
          one_type = one_type_ref.value
        end
        @generic_set_progress.call(id, nil) if !@generic_set_progress.nil?
      end

      # Free the memory
      @objects_state = {}

      # Return 'true' if YaST can solve deps. automatically
      if Pkg.PkgSolve(true) == true
        Builtins.y2milestone("Dependencies solved atomatically")
        return true
      end

      # Error message
      Report.Error(
        _(
          "Installation was unable to solve package dependencies automatically.\nSoftware manager will be opened for you to solve them manually."
        )
      )

      ret = false

      # BNC #Trying to solve deps. manually
      loop do
        Builtins.y2warning(
          "Cannot solve dependencies automatically, opening Packages UI"
        )
        diaret = PackagesUI.RunPackageSelector(
           "enable_repo_mgr" => false, "mode" => :summaryMode
        )
        Builtins.y2milestone("RunPackageSelector returned %1", diaret)

        # User didn't solve the deps manually
        if diaret == :cancel
          ret = false
          if Popup.ConfirmAbort(:unusable)
            Builtins.y2warning("User abort...")
            break
          end
          # Aborting not confirmed, next round
          next
          # Solved! (somehow)
        else
          ret = true
          break
        end
      end

      Builtins.y2milestone("Dependencies solved: %1", ret)
      ret
    end

    # <-- Storing and restoring states

    def FreeInternalVariables
      @last_patterns_selected = []
      @_images = {}
      @_image_order = []
      @images_details = {}
      @_mounted_images = []
      @selected_images = {}

      nil
    end

    # Only for checking in tests now
    attr_reader :selected_images

    publish function: :SetRepo, type: "void (integer)"
    publish variable: :last_patterns_selected, type: "list <string>"
    publish variable: :changed_by_user, type: "boolean"
    publish variable: :image_installation_available, type: "boolean"
    publish function: :ImageOrder, type: "list <string> ()"
    publish function: :SetDeployTarImageProgress, type: "void (void (integer))"
    publish function: :SetDownloadTarImageProgress, type: "void (boolean (integer, integer, integer))"
    publish function: :SetStartDownloadImageProgress, type: "void (void (string, string))"
    publish function: :SetOverallDeployingProgress, type: "void (void (string, integer))"
    publish function: :TotalSize, type: "integer ()"
    publish function: :GetCurrentImageDetails, type: "map <string, any> ()"
    publish function: :DeployImage, type: "boolean (string, string)"
    publish function: :DeployImageTemporarily, type: "boolean (string, string)"
    publish function: :CleanTemporaryImage, type: "boolean (string, string)"
    publish function: :FillUpImagesDetails, type: "boolean ()"
    publish function: :DeployImages, type: "boolean (list <string>, string, void (integer, integer))"
    publish function: :FindImageSet, type: "boolean (list <string>)"
    publish function: :ImagesToUse, type: "map ()"
    publish function: :FileSystemCopy, type: "boolean (string, string, integer, integer)"
    publish function: :GetProgressLayoutDetails, type: "integer (string, string)"
    publish function: :GetProgressLayoutLabel, type: "string (string)"
    publish function: :AdjustProgressLayout, type: "void (string, integer, string)"
    publish function: :StoreAllChanges, type: "void ()"
    publish function: :RestoreAllChanges, type: "boolean ()"
    publish function: :FreeInternalVariables, type: "void ()"
    publish function: :PrepareOEMImage, type: "void ()"
  end

  ImageInstallation = ImageInstallationClass.new
  ImageInstallation.main
end

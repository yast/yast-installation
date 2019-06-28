# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

#
# This is a library for cleaning up the inst-sys on low memory systems.
# The goal is to have enough free memory so the installation can finish successfuly.
#

require "fileutils"

require "yast"
require "yast/logger"
# memory size detection
require "yast2/hw_detection"
require "yast2/execute"

module Installation
  class InstsysCleaner
    extend Yast::Logger

    Yast.import "Mode"
    Yast.import "Stage"
    Yast.import "UI"

    # memory limit for removing the kernel modules from inst-sys (1GB)
    KERNEL_MODULES_WATERLINE = 1 << 30
    KERNEL_MODULES_MOUNT_POINT = "/parts/mp_0000".freeze

    # memory limit for removing the libzypp metadata cache (<640MB in text mode, <1GB in GUI)
    LIBZYPP_WATERLINE_TUI = 640 << 20
    LIBZYPP_WATERLINE_GUI = 1 << 30
    # the cache in inst-sys, the target system cache is at /mnt/...,
    # in upgrade mode the target cache is kept
    LIBZYPP_CACHE_PATH = "/var/cache/zypp/raw".freeze

    # files which can be removed from the libzypp "raw" cache in inst-sys (globs),
    # not needed for package installation
    LIBZYPP_CLEANUP_PATTERNS = [
      # repository meta data already included in the "solv" cache,
      "*-deltainfo.xml.gz",
      "*-primary.xml.gz",
      "*-susedata.xml.gz",
      "*-susedata.*.xml.gz",
      "*-susedinfo.xml.gz",
      "*-updateinfo.xml.gz",
      # product licenses (already confirmed)
      "*-license-*.tar.gz",
      # application meta data
      "*-appdata.xml.gz",
      "*-appdata-icons.tar.gz",
      "appdata-ignore.xml.gz",
      "appdata-screenshots.tar"
    ].freeze

    def self.libzypp_waterline
      Yast::UI.TextMode ? LIBZYPP_WATERLINE_TUI : LIBZYPP_WATERLINE_GUI
    end

    # Remove some files in inst-sys to have more free space if the system
    # has too low memory. If the system has enough memory keep everything in place.
    # This method might remove the kernel modules from the system, make sure
    # *all* needed kernel modules are aready loaded before calling this method.
    def self.make_clean
      # just a sanity check to make sure it's not called in an unexpected situation
      if !Yast::Stage.initial || !(Yast::Mode.installation || Yast::Mode.update || Yast::Mode.auto)
        log.warn("Skipping inst-sys cleanup (not in installation/update)")
        return
      end

      # memory size in bytes
      memory = Yast2::HwDetection.memory

      # run the cleaning actions depending on the available memory
      unmount_kernel_modules if memory < KERNEL_MODULES_WATERLINE
      cleanup_zypp_cache if memory < libzypp_waterline
    end

    ########################## Internal methods ################################

    # Remove the libzypp downloaded repository metadata.
    # Libzypp has "raw" and "solv" caches, the "solv" is built from "raw"
    # but it cannot be removed because libzypp keeps the files open.
    # The "raw" files will be later downloaded automatically again when loading
    # the repositories. But libzypp still need some files during package
    # installation, we can only remove the known files, @see LIBZYPP_CLEANUP_PATTERNS
    def self.cleanup_zypp_cache
      log.info("Cleaning unused files in the libzypp cache (#{LIBZYPP_CACHE_PATH})")
      saved_space = 0

      LIBZYPP_CLEANUP_PATTERNS.each do |p|
        files = Dir[File.join(LIBZYPP_CACHE_PATH, "**", p)]
        next if files.empty?

        files.each do |f|
          log.debug("Removing cache file #{f}")
          saved_space += File.size(f)
          # make sure we do not collide with Yast::FileUtils...
          ::FileUtils.rm(f)
        end
      end

      # convert to kiB
      saved_space /= 1024
      log.info("Libzypp cache cleanup saved #{saved_space}kiB (#{saved_space / 1024}MiB)")
    end

    # Remove the kernel modules squashfs image.
    # It assumes that all needed kernel drivers are already loaded and active
    # so we can remove the files to save some space.
    # The result highly depends on the architecture, the number of available
    # kernel modules can vary significantly. This saves about 29MB on x86_64
    # and about 5MB on s390x.
    def self.unmount_kernel_modules
      if !File.exist?(File.join(KERNEL_MODULES_MOUNT_POINT, "lib/modules"))
        log.warn("Kernel modules not found at #{KERNEL_MODULES_MOUNT_POINT}")
        log.warn("Skipping module cleanup")
        return
      end

      log.info("Removing the kernel modules inst-sys image")
      log_space_usage("Before removing the kernel modules:")

      # find the image for the mount point
      device = find_device || return
      image = losetup_backing_file(device) || return

      # unmount the image
      Yast::Execute.locally("umount", KERNEL_MODULES_MOUNT_POINT)

      # remove the loop device binding
      Yast::Execute.locally("losetup", "-d", device)

      # remove the image file
      ::FileUtils.rm_rf(image)

      log_space_usage("After removing the kernel modules:")
    end

    # Log the memory and disk usage to see how the clean up was effective
    def self.log_space_usage(msg)
      log.info(msg)
      # the Cheetah backend by default logs the output
      Yast::Execute.locally("df", "-m")
      Yast::Execute.locally("free", "-m")
    end

    # Find the device for the kernel modules mount point.
    # @return [String,nil] device name (/dev/loopN) or nil if not found
    def self.find_device
      mounts = Yast::Execute.locally("mount", stdout: :capture).split("\n")
      mounts.find do |m|
        m.match(/\A(\/dev\/loop.*) on #{Regexp.escape(KERNEL_MODULES_MOUNT_POINT)} /)
      end
      device = Regexp.last_match(1)

      if !device
        log.warn("Cannot find the loop device for the #{KERNEL_MODULES_MOUNT_POINT} mount point")
      end

      device
    end

    # Find the backend file for a loop device.
    # @param device [String] device name
    # @return [String,nil] backing file or nil if not found
    def self.losetup_backing_file(device)
      # find the backend file for the loop device
      file = Yast::Execute.locally("losetup", "-n", "-O", "BACK-FILE",
        device, stdout: :capture).strip

      if file.nil? || file.empty?
        log.warn("Cannot find the backend file for the #{device} device")
        return nil
      end

      file
    end

    private_class_method :log_space_usage, :unmount_kernel_modules,
      :cleanup_zypp_cache, :find_device, :losetup_backing_file
  end
end

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
require "shellwords"
require "English"

require "yast"
require "yast/logger"
# memory size detection
require "yast2/hw_detection"

module Installation
  class InstsysCleaner
    extend Yast::Logger

    Yast.import "Mode"
    Yast.import "Stage"

    # memory limit for removing the kernel modules from inst-sys (1GB)
    KERNEL_MODULES_WATERLINE = 1 << 30
    KERNEL_MODULES_MOUNT_POINT = "/parts/mp_0000".freeze

    # memory limit for removing the libzypp metadata cache (640MB)
    LIBZYPP_WATERLINE = 640 << 20
    # the cache in inst-sys, the target system cache is at /mnt/...,
    # in upgrade mode the target cache is kept
    LIBZYPP_CACHE_PATH = "/var/cache/zypp/raw".freeze

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
      cleanup_zypp_cache if memory < LIBZYPP_WATERLINE
    end

    ########################## Internal methods ################################

    # Remove the libzypp downloaded repository metadata.
    # Libzypp has "raw" and "solv" caches, the "solv" is built from "raw"
    # but it cannot be removed because libzypp keeps the files open.
    # The "raw" files will be later downloaded automatically again when loading
    # the repositories.
    def self.cleanup_zypp_cache
      log.info("Removing libzypp cache (#{LIBZYPP_CACHE_PATH})")
      log_space_usage("Before removing libzypp cache:")

      # make sure we do not collide with Yast::FileUtils...
      ::FileUtils.rm_rf(LIBZYPP_CACHE_PATH)

      log_space_usage("After removing libzypp cache:")
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

      # find the loop device for the mount point
      mounts = `mount`.split("\n")
      mounts.find { |m| m.match(/\A(\/dev\/loop.*) on #{Regexp.escape(KERNEL_MODULES_MOUNT_POINT)} /) }

      device = Regexp.last_match(1)
      if !device
        log.warn("Cannot find the loop device for the #{KERNEL_MODULES_MOUNT_POINT} mount point")
        return
      end

      # find the backend file for the loop device
      file = `losetup -n -O BACK-FILE #{Shellwords.escape(device)}`.strip

      if file.nil? || file.empty?
        log.warn("Cannot find the backend file for the #{device} device")
        return
      end

      # unmount the loop device
      `umount #{KERNEL_MODULES_MOUNT_POINT}`
      if $CHILD_STATUS && !$CHILD_STATUS.success?
        log.warn("Unmouting #{KERNEL_MODULES_MOUNT_POINT} failed")
        return
      end

      # remove the loop device binding
      `losetup -d #{Shellwords.escape(device)}`
      if $CHILD_STATUS && !$CHILD_STATUS.success?
        log.warn("Detaching loopback device #{device} failed")
        return
      end

      # remove the image file
      ::FileUtils.rm_rf(file)

      log_space_usage("After removing the kernel modules:")
    end

    def self.log_space_usage(msg)
      log.info(msg)
      log.info("disk usage in MB ('df -m'):")
      log.info(`df -m`)
      log.info("memory usage in MB ('free -m'):")
      log.info(`free -m`)
    end

    private_class_method :log_space_usage, :unmount_kernel_modules,
      :cleanup_zypp_cache
  end
end

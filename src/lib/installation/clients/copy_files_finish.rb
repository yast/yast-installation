# encoding: utf-8

# Copyright (c) [2006-2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "fileutils"
require "installation/ssh_importer"
require "installation/finish_client"

require "shellwords"

Yast.import "Pkg"
Yast.import "Arch"
Yast.import "Linuxrc"
Yast.import "Installation"
Yast.import "Directory"
Yast.import "Mode"
Yast.import "Packages"
Yast.import "ProductControl"
Yast.import "ProductProfile"
Yast.import "String"
Yast.import "WorkflowManager"
Yast.import "SystemFilesCopy"
Yast.import "InstFunctions"

module Yast
  # Step of base installation finish including mainly files to copy from insts-sys to target system
  # @note This client expect that SCR is not yet switched.
  #   Expect the hell to be frozen if you call it with switched SCR.
  class CopyFilesFinishClient < ::Installation::FinishClient
    include Yast::I18n

    def initialize
      textdomain "installation"
    end

    def modes
      [:installation, :update, :autoinst]
    end

    def title
      _("Copying files to installed system...")
    end

    # @raise RuntimeError if called with switched SCR to have defined behavior and prevent
    #   accidental overwrite and data loss
    def write
      if Yast::WFM.scr_chrooted?
        raise "Calling CopyFilesFinish client with SCR switched to #{Yast::WFM.scr_root}"
      end

      # bugzilla #221815 and #485980
      # Adding blacklisted modules into the /etc/modprobe.d/50-blacklist.conf
      # This should run before the SCR::switch function
      adjust_modprobe_blacklist

      copy_hardware_status
      copy_vnc
      copy_multipath
      # Copy cio_ignore whitelist (bsc#1095033)
      copy_active_devices

      handle_second_stage

      # Copy control.xml so it can be read once again during continue mode
      # FIXME: probably won't work as expected with new multimedia layout.
      #   Ideally final modified control.xml should be saved.
      copy_control_file

      # Copy /media.1/media to the installed system (fate#311377)
      # Formerly /media.1/build (bsc#1062297)
      copy_media_file
      copy_product_profiles

      # List of files used as additional workflow definitions
      # TODO check if it is still needed
      copy_all_workflow_files

      # Copy files from inst-sys to the just installed system
      # FATE #301937, items are defined in the control file
      SystemFilesCopy.SaveInstSysContent

      # bugzila #328126
      # Copy 70-persistent-cd.rules ... if not updating
      copy_hardware_udev_rules

      # fate#319624
      copy_ssh_files
      # Do not rely on copy_ssh_files returned value (bsc#1099104)
      nil
    end

  private

    def copy_product_profiles
      all_profiles = ProductProfile.all_profiles
      # copy all product profiles to the installed system (fate#310730)
      return if all_profiles.empty?

      target_dir = File.join(Installation.destdir, "/etc/productprofiles.d")
      ::FileUtils.mkdir_p(target_dir)
      all_profiles.each do |profile_path|
        log.info "Copying '#{profile_path}' to #{target_dir}"
        WFM.Execute(
          path(".local.bash"),
          "/usr/bin/cp -a #{profile_path.shellescape} #{target_dir.shellescape}/"
        )
      end
    end

    def copy_hardware_status
      log.info "Copying hardware information"
      destdir = ::File.join(installation_destination, "/var/lib")
      ::FileUtils.mkdir_p(destdir)
      WFM.Execute(
        path(".local.bash"),
        # BNC #596938: Files / dirs might be symlinks
        "/usr/bin/cp -a --recursive --dereference /var/lib/hardware #{destdir.shellescape}"
      )
    end

    def copy_all_workflow_files
      control_files = WorkflowManager.GetAllUsedControlFiles
      if !control_files || control_files.empty?
        log.info "No additional workflows"
        return
      end

      log.info "Copying additional control files #{control_files.inspect}"
      workflows_list = control_files.map do |one_filename|
        ::File.basename(one_filename)
      end

      # Remove the directory with all additional control files (if exists)
      # and create it again (empty). BNC #471454
      control_files_directory = ::File.join(installation_destination, Directory.etcdir, "control_files")
      ::FileUtils.rm_rf(control_files_directory)
      ::FileUtils.mkdir_p(control_files_directory)

      # BNC #475516: Writing the control-files-order index 'after' removing the directory
      # Control files need to follow the exact order, only those liseted here are used
      order_file = ::File.join(control_files_directory, "order.ycp")
      Yast::SCR.Write(
        path(".target.ycp"),
        order_file,
        workflows_list
      )
      ::FileUtils.chmod(0o644, ::File.join(order_file))

      # Now copy all the additional control files to the just installed system
      control_files.each do |file|
        ::FileUtils.cp(file, control_files_directory)
        ::FileUtils.chmod(0o644, ::File.join(control_files_directory, ::File.basename(file)))
      end
    end

    UDEV_RULES_DIR = "/etc/udev/rules.d".freeze

    # see bugzilla #328126
    def copy_hardware_udev_rules
      return if Mode.update
      udev_rules_destdir = ::File.join(installation_destination, UDEV_RULES_DIR)
      ::FileUtils.mkdir_p(udev_rules_destdir)

      # Copy all udev files, but do not overwrite those that already exist
      # on the system bnc#860089
      # They are (also) needed for initrd bnc#666079
      cmd = "/usr/bin/cp -avr --no-clobber #{UDEV_RULES_DIR}/. #{udev_rules_destdir.shellescape}"
      log.info "Copying all udev rules from #{UDEV_RULES_DIR} to #{udev_rules_destdir}"
      cmd_out = WFM.Execute(path(".local.bash_output"), cmd)

      log.error "Error copying udev rules with #{cmd_out.inspect}" if cmd_out["exit"] != 0
    end

    def copy_ssh_files
      log.info "Copying SSH keys and config files"
      ::Installation::SshImporter.instance.write(installation_destination)
    end

    # Function appends blacklisted modules to the /etc/modprobe.d/50-blacklist.conf
    # file.
    #
    # More information in bugzilla #221815 and #485980
    def adjust_modprobe_blacklist
      # check whether we need to run it
      brokenmodules = Linuxrc.InstallInf("BrokenModules")
      if !brokenmodules || brokenmodules.empty?
        log.info "No BrokenModules in install.inf, skipping..."
        return
      end

      # comma-separated list of modules
      blacklisted_modules = brokenmodules.split(", ")

      # run before SCR switch
      blacklist_file = ::File.join(
        installation_destination,
        "/etc/modprobe.d/50-blacklist.conf"
      )

      # read the content
      content = ""
      if ::File.exist?(blacklist_file)
        content = ::File.read(blacklist_file)
      else
        log.warn "File #{blacklist_file} does not exist, installation will create new one"
      end

      # creating new entries with comment
      blacklist_file_append = "# Note: Entries added during installation/update (Bug 221815)\n"
      blacklisted_modules.each do |blacklisted_module|
        blacklist_file_append << "blacklist #{blacklisted_module}\n"
      end

      # newline if the file is not empty
      content << "\n\n" unless content.empty?
      content << blacklist_file_append

      log.info "Blacklisting modules: #{blacklisted_modules} in #{blacklist_file}"
      ::File.write(blacklist_file, content)
    end

    def installation_destination
      ::Yast::Installation.destdir
    end

    def copy_vnc
      # if VNC, copy setup data
      return unless Linuxrc.vnc

      log.info "Copying VNC settings"
      WFM.Execute(
        path(".local.bash"),
        "/bin/cp -a /root/.vnc #{installation_destination.shellescape}/root/"
      )
    end

    # See {https://www.suse.com/support/kb/doc/?id=7001133}
    MULTIPATH_CONFIG_FILES = [
      "/etc/multipath.conf",
      "/etc/multipath/bindings",
      "/etc/multipath/wwids"
    ].freeze

    private_constant :MULTIPATH_CONFIG_FILES

    def copy_multipath
      # Only in install, as update should keep its old config
      return unless Mode.installation

      # Copy multipath stuff (bnc#885628, bsc#1133045)
      MULTIPATH_CONFIG_FILES.each do |config_file|
        next unless File.exist?(config_file)

        log.info "Copying multipath config file: '#{config_file}'"
        target_path = File.join(Installation.destdir, config_file)
        target_dir = File.dirname(target_path)
        ::FileUtils.mkdir_p(target_dir) unless File.exist?(target_dir)
        ::FileUtils.cp(config_file, target_path)
      end
    end

    def copy_active_devices
      # Only in install, as update should keep its old config
      return unless Mode.installation
      return unless Arch.s390

      path = "/boot/zipl/active_devices.txt"
      if File.exist?(path)
        log.info "Copying zipl active devices '#{path}'"
        target_path = File.join(Installation.destdir, path)
        ::FileUtils.mkdir_p(File.dirname(target_path))
        ::FileUtils.cp(path, target_path)
      end
    end

    def handle_second_stage
      # Copy /etc/install.inf into built system so that the
      # second phase of the installation can find it.
      Linuxrc.SaveInstallInf(Installation.destdir) if InstFunctions.second_stage_required?
    end

    def copy_control_file
      log.info "Copying YaST control file"
      destination = File.join(Installation.destdir, Directory.etcdir, "control.xml")
      ::FileUtils.mkdir_p(File.join(Installation.destdir, Directory.etcdir))
      ::FileUtils.cp(ProductControl.current_control_file, destination)
      ::FileUtils.chmod(0o644, destination)
    end

    def copy_media_file
      media_file = Pkg.SourceProvideOptionalFile(Packages.GetBaseSourceID, 1, "/media.1/media")

      if media_file
        log.info("Copying /media.1/media file to /media")
        media_destination = File.join(Installation.destdir, Directory.etcdir, "media")
        ::FileUtils.cp(media_file, media_destination)
        ::FileUtils.chmod(0o644, media_destination)

        # FIXME: `/build` is deprecated, only kept for backward compatibility. It must be removed
        # as soon it will not longer needed.
        log.info("Copying /media.1/media file to /build (backward compatibility)")
        build_destination = File.join(Installation.destdir, Directory.etcdir, "build")
        ::FileUtils.cp(media_file, build_destination)
        ::FileUtils.chmod(0o644, build_destination)
      else
        log.error("Cannot find /media.1/media file")
      end
    end
  end
end

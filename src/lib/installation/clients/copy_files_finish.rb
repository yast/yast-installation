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
#  copy_files_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
require "fileutils"
require "installation/ssh_importer"

module Yast
  class CopyFilesFinishClient < Client
    include Yast::Logger

    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "installation"

      Yast.import "AddOnProduct"
      Yast.import "Linuxrc"
      Yast.import "Installation"
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Packages"
      Yast.import "ProductControl"
      Yast.import "ProductProfile"
      Yast.import "FileUtils"
      Yast.import "String"
      Yast.import "WorkflowManager"
      Yast.import "SystemFilesCopy"
      Yast.import "ProductFeatures"
      Yast.import "InstFunctions"

      Yast.include self, "installation/misc.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting copy_files_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Copying files to installed system..."
          ),
          "when"  => [:installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # bugzilla #221815 and #485980
        # Adding blacklisted modules into the /etc/modprobe.d/50-blacklist.conf
        # This should run before the SCR::switch function
        AdjustModprobeBlacklist()

        # copy hardware status to installed system
        Builtins.y2milestone("Copying hardware information")
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            # BNC #596938: Files / dirs might be symlinks
            "mkdir -p '%1/var/lib/'; /bin/cp -a --recursive --dereference '/var/lib/hardware' '%1/var/lib/'",
            String.Quote(Installation.destdir)
          )
        )

        # if VNC, copy setup data
        if Linuxrc.vnc
          Builtins.y2milestone("Copying VNC settings")
          WFM.Execute(
            path(".local.bash"),
            Builtins.sformat(
              "/bin/cp -a '/root/.vnc' '%1/root/'",
              String.Quote(Installation.destdir)
            )
          )
        end

        # Copy multipath stuff (bnc#885628)
        # Only in install, as update should keep its old config
        if Mode.installation
          multipath_config = "/etc/multipath/wwids"
          if File.exist?(multipath_config)
            log.info "Copying multipath blacklist '#{multipath_config}'"
            target_path = File.join(Installation.destdir, multipath_config)
            ::FileUtils.mkdir_p(File.dirname(target_path))
            ::FileUtils.cp(multipath_config, target_path)
          end
        end

        # Copy cio_ignore whitelist (bsc#1095033)
        # Only in install, as update should keep its old config
        if Mode.installation
          path = "/boot/zipl/active_devices.txt"
          if File.exist?(path)
            log.info "Copying zipl active devices '#{path}'"
            target_path = File.join(Installation.destdir, path)
            ::FileUtils.mkdir_p(File.dirname(target_path))
            ::FileUtils.cp(multipath_config, target_path)
          end
        end

        # --------------------------------------------------------------
        # Copy /etc/install.inf into built system so that the
        # second phase of the installation can find it.
        if InstFunctions.second_stage_required?
          Linuxrc.SaveInstallInf(Installation.destdir)
        else
          SCR.Execute(path(".target.remove"), "/etc/install.inf")
        end

        # Copy control.xml so it can be read once again during continue mode
        Builtins.y2milestone("Copying YaST control file")
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp '%1' '%2%3/control.xml' && /bin/chmod 0644 '%2%3/control.xml'",
            String.Quote(ProductControl.current_control_file),
            String.Quote(Installation.destdir),
            String.Quote(Directory.etcdir)
          )
        )

        # Copy /media.1/build to the installed system (fate#311377)
        @src_id = Packages.GetBaseSourceID
        @build_file = Pkg.SourceProvideOptionalFile(
          @src_id,
          1,
          "/media.1/build"
        )
        if !@build_file.nil?
          Builtins.y2milestone("Copying /media.1/build file")
          WFM.Execute(
            path(".local.bash"),
            Builtins.sformat(
              "/bin/cp '%1' '%2%3/' && /bin/chmod 0644 '%2%3/build'",
              String.Quote(@build_file),
              String.Quote(Installation.destdir),
              String.Quote(Directory.etcdir)
            )
          )
        end

        # copy all product profiles to the installed system (fate#310730)
        if ProductProfile.all_profiles != []
          @target_dir = Builtins.sformat(
            "%1/etc/productprofiles.d",
            Installation.destdir
          )
          if !FileUtils.Exists(@target_dir)
            SCR.Execute(path(".target.mkdir"), @target_dir)
          end
          Builtins.foreach(ProductProfile.all_profiles) do |profile_path|
            Builtins.y2milestone(
              "Copying '%1' to %2/",
              profile_path,
              @target_dir
            )
            WFM.Execute(
              path(".local.bash"),
              Builtins.sformat(
                "/bin/cp -a '%1' '%2/'",
                String.Quote(profile_path),
                String.Quote(@target_dir)
              )
            )
          end
        end

        # List of files used as additional workflow definitions
        CopyAllWorkflowFiles()

        # Copy files from inst-sys to the just installed system
        # FATE #301937, items are defined in the control file
        SystemFilesCopy.SaveInstSysContent

        # bugzila #328126
        # Copy 70-persistent-cd.rules ... if not updating
        CopyHardwareUdevRules() if !Mode.update

        # fate#319624
        copy_ssh_files
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("copy_files_finish finished")
      deep_copy(@ret)
    end

    def CopyAllWorkflowFiles
      if Builtins.size(WorkflowManager.GetAllUsedControlFiles) == 0
        Builtins.y2milestone("No additional workflows")
        return
      end

      Builtins.y2milestone(
        "Coping additional control files %1",
        WorkflowManager.GetAllUsedControlFiles
      )
      workflows_list = []

      Builtins.foreach(WorkflowManager.GetAllUsedControlFiles) do |one_filename|
        if Builtins.regexpmatch(one_filename, "/")
          one_filename = Builtins.regexpsub(one_filename, "^.*/(.*)", "\\1")
        end
        workflows_list = Builtins.add(workflows_list, one_filename)
      end

      # Remove the directory with all additional control files (if exists)
      # and create it again (empty). BNC #471454
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "rm -rf '%1'; /bin/mkdir -p '%1'",
          String.Quote(
            Ops.add(
              Ops.add(Installation.destdir, Directory.etcdir),
              "/control_files"
            )
          )
        )
      )

      # BNC #475516: Writing the control-files-order index 'after' removing the directory
      # Control files need to follow the exact order, only those liseted here are used
      SCR.Write(
        path(".target.ycp"),
        Ops.add(
          Ops.add(Installation.destdir, Directory.etcdir),
          "/control_files/order.ycp"
        ),
        workflows_list
      )
      SCR.Execute(
        path(".target.bash"),
        Ops.add(
          Ops.add(
            Ops.add(
              "/bin/chmod 0644 " + "'",
              String.Quote(Installation.destdir)
            ),
            Directory.etcdir
          ),
          "/control_files/order.ycp'"
        )
      )

      # Now copy all the additional control files to the just installed system
      Builtins.foreach(WorkflowManager.GetAllUsedControlFiles) do |file|
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(Ops.add("/bin/cp '", String.Quote(file)), "' "),
                  "'"
                ),
                String.Quote(Installation.destdir)
              ),
              Directory.etcdir
            ),
            "/control_files/'"
          )
        )
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    "/bin/chmod 0644 " + "'",
                    String.Quote(Installation.destdir)
                  ),
                  Directory.etcdir
                ),
                "/control_files/"
              ),
              String.Quote(file)
            ),
            "'"
          )
        )
      end

      nil
    end

    UDEV_RULES_DIR = "/etc/udev/rules.d".freeze

    # see bugzilla #328126
    def CopyHardwareUdevRules
      udev_rules_destdir = File.join(Installation.destdir, UDEV_RULES_DIR)

      if !FileUtils.Exists(udev_rules_destdir)
        log.info "Directory #{udev_rules_destdir} does not exist yet, creating it"
        WFM.Execute(path(".local.bash"), "mkdir -p #{udev_rules_destdir}")
      end

      # Copy all udev files, but do not overwrite those that already exist
      # on the system bnc#860089
      # They are (also) needed for initrd bnc#666079
      cmd = "cp -avr --no-clobber #{UDEV_RULES_DIR}/. #{udev_rules_destdir}"
      log.info "Copying all udev rules from #{UDEV_RULES_DIR} to #{udev_rules_destdir}"
      cmd_out = WFM.Execute(path(".local.bash_output"), cmd)

      log.error "Error copying udev rules" if cmd_out["exit"] != 0

      nil
    end

    def copy_ssh_files
      log.info "Copying SSH keys and config files"
      ::Installation::SshImporter.instance.write(Installation.destdir)
    end

    # Prevent from re-defining client class
    # Re-defining would produce warnings that constants were already initialized
  end unless defined? CopyFilesFinishClient
end

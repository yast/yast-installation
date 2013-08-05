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
# $Id$
#
module Yast
  class CopyFilesFinishClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "installation"

      Yast.import "AddOnProduct"
      Yast.import "Linuxrc"
      Yast.import "Installation"
      Yast.import "Directory"
      Yast.import "Packages"
      Yast.import "ProductControl"
      Yast.import "ProductProfile"
      Yast.import "FileUtils"
      Yast.import "String"
      Yast.import "WorkflowManager"
      Yast.import "SystemFilesCopy"
      Yast.import "ProductFeatures"

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


        # --------------------------------------------------------------
        # Copy /etc/install.inf into built system so that the
        # second phase of the installation can find it.
        Linuxrc.SaveInstallInf(Installation.destdir)

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
        if @build_file != nil
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

        # Remove old eula.txt
        # bugzilla #208908
        @eula_txt = Builtins.sformat(
          "%1%2/eula.txt",
          Installation.destdir,
          Directory.etcdir
        )
        if FileUtils.Exists(@eula_txt)
          SCR.Execute(path(".target.remove"), @eula_txt)
        end

        # FATE #304865: Enhance YaST Modules to cooperate better handling the product licenses
        @license_dir = ProductFeatures.GetStringFeature(
          "globals",
          "base_product_license_directory"
        )
        if @license_dir == nil || @license_dir == ""
          @license_dir = Builtins.sformat(
            "%1%2/licenses/base/",
            Installation.destdir,
            Directory.etcdir
          )
          Builtins.y2warning(
            "No 'base_product_license_directory' set, using %1",
            @license_dir
          )
        else
          @license_dir = Builtins.sformat(
            "%1/%2",
            Installation.destdir,
            @license_dir
          )
          Builtins.y2milestone("Using license dir: %1", @license_dir)
        end

        # BNC #594042: Multiple license locations
        @license_locations = ["/usr/share/doc/licenses/", "/"]

        Builtins.foreach(@license_locations) do |license_location|
          license_location = Builtins.sformat(
            "%1/license.tar.gz",
            license_location
          )
          next if !FileUtils.Exists(license_location)
          # Copy licenses so it can be used in firstboot later
          # bnc #396976
          cmd = Convert.to_map(
            WFM.Execute(
              path(".local.bash_output"),
              Builtins.sformat(
                "mkdir -p '%1' && cd '%1' && rm -rf license*.*; cd '%1' && tar -xf '%2'",
                String.Quote(@license_dir),
                String.Quote(license_location)
              )
            )
          )
          if Ops.get_integer(cmd, "exit", -1) == 0
            Builtins.y2milestone(
              "Copying %1 to %2 was successful",
              license_location,
              @license_dir
            )
          else
            Builtins.y2error(
              "Copying %1 to %2 has failed: %3",
              license_location,
              @license_dir,
              cmd
            )
          end
          raise Break
        end

        # bugzila #328126
        # Copy 70-persistent-cd.rules ... if not updating
        CopyHardwareUdevRules() if !Mode.update
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

    # see bugzilla #328126
    def CopyHardwareUdevRules
      udev_rules_srcdir = "/etc/udev/rules.d/"
      udev_rules_destdir = Builtins.sformat(
        "%1%2",
        Installation.destdir,
        udev_rules_srcdir
      )

      if !FileUtils.Exists(udev_rules_destdir)
        Builtins.y2milestone(
          "%1 does not exist yet, creating it",
          udev_rules_destdir
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat("mkdir -p '%1'", udev_rules_destdir)
        )
      end

      # udev files that should be copied
      # Copy network rules early to get them to initrd, bnc#666079
      files_to_copy = ["70-persistent-cd.rules", "70-persistent-net.rules"]

      Builtins.foreach(files_to_copy) do |one_file|
        one_file_from = Builtins.sformat("%1%2", udev_rules_srcdir, one_file)
        one_file_to = Builtins.sformat("%1%2", udev_rules_destdir, one_file)
        if !FileUtils.Exists(one_file_from)
          Builtins.y2error("Cannot copy non-existent file: %1", one_file_from)
        elsif FileUtils.Exists(one_file_to)
          Builtins.y2milestone("File %1 exists, skipping", one_file_to)
        else
          cmd = Builtins.sformat(
            "cp -a '%1' '%2'",
            String.Quote(one_file_from),
            String.Quote(udev_rules_destdir)
          )
          cmd_out = Convert.to_map(WFM.Execute(path(".local.bash_output"), cmd))

          if Ops.get_integer(cmd_out, "exit", -1) != 0
            Builtins.y2error("Command failed '%1': %2", cmd, cmd_out)
          else
            Builtins.y2milestone("Copied to %1", one_file_to)
          end
        end
      end

      nil
    end
  end
end

Yast::CopyFilesFinishClient.new.main

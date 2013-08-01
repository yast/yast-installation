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
#  save_config_finish.ycp
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
  class SaveConfigFinishClient < Client
    def main

      textdomain "installation"

      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Timezone"
      Yast.import "Language"
      Yast.import "Keyboard"
      Yast.import "ProductFeatures"
      Yast.import "AutoInstall"
      Yast.import "Console"
      Yast.import "Product"
      Yast.import "Progress"
      Yast.import "SignatureCheckDialogs"
      Yast.import "Stage"
      Yast.import "AddOnProduct"
      Yast.import "FileUtils"
      Yast.import "Installation"
      Yast.import "String"


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

      Builtins.y2milestone("starting save_config_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => Mode.autoinst ? 7 : Mode.update ? 5 : 6,
          "when"  => [:installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # Bugzilla #209119
        # ProductFeatures::Save() moved here from inst_kickoff.ycp
        # (After the SCR is switched)
        if Stage.initial
          Builtins.y2milestone("Saving ProductFeatures...")
          SCR.Execute(path(".target.bash"), "/bin/mkdir -p '/etc/YaST2'")
          SCR.Execute(
            path(".target.bash"),
            "touch '/etc/YaST2/ProductFeatures'"
          )
          ProductFeatures.Save
        end

        # Bugzilla #187558
        # Save Add-On products configuration
        # to be able to restore the settings
        @save_to = AddOnProduct.TmpExportFilename
        if FileUtils.Exists(@save_to)
          SCR.Execute(path(".target.remove"), @save_to)
        end
        if Stage.initial
          Builtins.y2milestone("Saving Add-On configuration...")
          @exported_add_ons = AddOnProduct.Export
          if @exported_add_ons == nil
            Builtins.y2error("Error, Add-Ons returned 'nil'")
          else
            @saved = SCR.Write(path(".target.ycp"), @save_to, @exported_add_ons)
            if @saved
              Builtins.y2milestone("Add-Ons configuration saved successfuly")
            else
              Builtins.y2error(
                "Error occurred when storing Add-Ons configuration!"
              )
            end
          end
        end

        if !Mode.update
          # progress step title
          Progress.Title(_("Saving time zone..."))
          # clock must be set correctly in new chroot
          Timezone.Set(Timezone.timezone, true)
          Timezone.Save
        end

        Progress.NextStep
        if !Mode.update
          # progress step title
          Progress.Title(_("Saving language..."))
          Language.Save
          Progress.NextStep

          # progress step title
          Progress.Title(_("Saving console configuration..."))
          Console.Save
          Progress.NextStep
        else
          @lang = Language.language
          @file = Ops.add(Directory.vardir, "/language.ycp")
          Builtins.y2milestone(
            "saving %1 to %2 for 2nd stage of update",
            @lang,
            @file
          )
          SCR.Write(
            path(".target.ycp"),
            @file,
            { "second_stage_language" => @lang }
          )
        end
        # progress step title
        Progress.Title(_("Saving keyboard configuration..."))
        Keyboard.Save
        Progress.NextStep
        # progress step title
        Progress.Title(_("Saving product information..."))
        ProductFeatures.Save
        if Mode.autoinst || Mode.autoupgrade
          Progress.NextStep
          # progress step title
          Progress.Title(_("Saving automatic installation settings..."))
          AutoInstall.Save
        end
        Progress.NextStep
        # progress step title
        Progress.Title(_("Configuring the superuser's environment..."))
        SCR.Write(
          path(".sysconfig.suseconfig.CWD_IN_USER_PATH"),
          Builtins.contains(Product.flags, "usercwd") ? "yes" : "no"
        )
        SCR.Write(path(".sysconfig.suseconfig"), nil)

        Progress.NextStep
        # progress step title
        Progress.Title(_("Saving security settings..."))
        SCR.Write(
          path(".sysconfig.security.CHECK_SIGNATURES"),
          SignatureCheckDialogs.CheckSignatures
        )
        SCR.Write(path(".sysconfig.security"), nil)

        Progress.NextStep
        # progress step title
        Progress.Title(_("Saving boot scripts settings..."))
        @run_in_parallel = ProductFeatures.GetBooleanFeature(
          "globals",
          "run_init_scripts_in_parallel"
        )
        SCR.Write(
          path(".sysconfig.boot.RUN_PARALLEL"),
          @run_in_parallel ? "yes" : "no"
        )
        SCR.Write(path(".sysconfig.boot"), nil)

        # save supportconfig
        if Ops.greater_than(
            SCR.Read(path(".target.size"), "/etc/install.inf"),
            0
          )
          @url = Convert.to_string(
            SCR.Read(path(".etc.install_inf.supporturl"))
          )
          Builtins.y2milestone("URL value from /etc/install.inf : %1", @url)
          if @url != nil && Ops.greater_than(Builtins.size(@url), 0)
            @config_path = Builtins.sformat(
              "%1%2",
              String.Quote(Installation.destdir),
              "/etc/supportconfig.conf"
            )
            Builtins.y2milestone(
              "URL from install.inf readed, test if %1 exists",
              @config_path
            )
            if FileUtils.Exists(@config_path)
              Builtins.y2milestone(
                "Insert value into supportconfig.conf: %1",
                @url
              )
              SCR.Execute(
                path(".target.bash_output"),
                Builtins.sformat(
                  "sed -i '/VAR_OPTION_UPLOAD_TARGET=.*/d;/^$/d' %1",
                  @config_path
                )
              )
              SCR.Execute(
                path(".target.bash_output"),
                Builtins.sformat(
                  "echo \"VAR_OPTION_UPLOAD_TARGET='%1'\">> %2",
                  @url,
                  @config_path
                )
              )
            else
              Builtins.y2error("filename %1 was not found", @config_path)
            end
          end
        else
          Builtins.y2warning("/etc/install.inf not found")
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("save_config_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::SaveConfigFinishClient.new.main

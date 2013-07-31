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
#      include/installation/scr_switch_debugger.ycp
#
# Module:
#      System installation
#
# Summary:
#      Debugs SCR switch failure
#
# Authors:
#      Lukas Ocilka <locilka@suse.cz>
#
module Yast
  module InstallationScrSwitchDebuggerInclude
    def initialize_installation_scr_switch_debugger(include_target)
      Yast.import "UI"
      textdomain "installation"

      # ATTENTION: This functionality is called when SCR switch fails.
      #            It means that there is (probably) no other SCR running
      #            and we have to create one first.

      Yast.import "FileUtils"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Icon"
      Yast.import "Installation"
      Yast.import "HTML"
      Yast.import "String"

      # test result (Checking for xyz... Passed)
      @result_ok = _("Passed")
      # test result (Checking for xyz... Failed)
      @result_failed = "Failed"

      # *********************************************************************

      # --> Configuration

      # path of of the failed chroot (SCROpen)
      # assigned in main function RunSCRSwitchDebugger()
      @chroot_path = nil

      # SCR of the inst-sys
      @new_SCR_path = "/"

      # chroot binary
      @test_chroot_binary = "/usr/bin/chroot"

      # binary for 'any' command exists
      @test_binary_exists = "/bin/ls"

      # any command for the chroot command
      @test_do_chroot = "/bin/ls -1 /"

      # y2base path
      @test_y2base = "/usr/lib/YaST2/bin/y2base"

      # get all installed rpm packages
      @test_rpm = "rpm -qa"

      # all needed rpm packages
      @needed_rpm_packages = [
        "yast2",
        "yast2-installation",
        "yast2-core",
        "yast2-bootloader",
        "yast2-packager"
      ]

      # is the package %1 installed?
      @test_one_rpm = "rpm -q %1"

      # what requires the %1 package?
      @test_requires = "rpm -q --requires %1"

      # what provides the %1 object (can contain "()"s)
      @test_whatprovides = "rpm -q --whatprovides '%1'"

      # where logs are stored
      @yast_logs = "/var/log/YaST2/"

      # YaST log file
      @yast_logfile = "y2log"

      @YaST_log_lines = []
    end

    # <-- Configuration

    # *********************************************************************

    # --> Helper Functions

    # UI dialog
    def SCRSwitchDialog
      VBox(
        Left(
          HBox(
            HSquash(MarginBox(0.5, 0.2, Icon.Error)),
            # heading
            Heading(_("Switching to the Installed System Failed"))
          )
        ),
        VSpacing(0.5),
        # informative text
        MarginBox(
          1,
          1,
          VBox(
            Left(
              Label(
                Builtins.sformat(
                  # TRANSLATORS: an error message
                  # %1 - logfile, possibly with errors
                  # %2 - link to our bugzilla
                  # %3 - directory where YaST logs are stored
                  # %4 - link to the Yast Bug Reporting HOWTO Web page
                  _(
                    "Switching to the installed system has failed.\n" +
                      "Find more information near the end of the '%1' file.\n" +
                      "\n" +
                      "This is worth reporting a bug at %2.\n" +
                      "Please, attach all YaST logs stored in the '%3' directory.\n" +
                      "See %4 for more information about YaST logs.\n"
                  ),
                  "/var/log/YaST2/y2log",
                  "http://bugzilla.novell.com/",
                  "/var/log/YaST2/",
                  # link to the Yast Bug Reporting HOWTO
                  # for translators: use the localized page for your language if it exists,
                  # check the combo box "In other laguages" on top of the page
                  _("http://en.opensuse.org/openSUSE:Report_a_YaST_bug")
                )
              )
            )
          )
        ),
        MarginBox(
          1,
          1,
          VBox(
            MinWidth(
              70,
              # used for progress
              LogView(
                Id(:log_view),
                # log-view label
                _("&Checking the Installed System..."),
                18,
                500
              )
            ),
            ReplacePoint(Id(:dialog_rp), Empty())
          )
        )
      )
    end

    # reports a progress with reslt
    def ReportTest(test_description, test_result)
      # report it to the log
      Builtins.y2milestone("%1 %2", test_description, test_result)

      # report it to the UI
      UI.ChangeWidget(
        Id(:log_view),
        :LastLine,
        Builtins.sformat(
          "%1 %2\n",
          test_description,
          test_result ? @result_ok : @result_failed
        )
      )

      if test_result
        # passed
        return
      end

      Builtins.y2error("-- I.C. Winner --")

      UI.ChangeWidget(
        Id(:log_view),
        :LastLine,
        Ops.add(
          Ops.add(
            "\n",
            Builtins.sformat(
              # TRANSLATORS: an error message
              # %1 - link to our bugzilla
              # %2 - directory where YaST logs are stored
              _(
                "This is worth reporting a bug at %1.\nPlease, attach all YaST logs stored in the '%2' directory.\n"
              ),
              "http://bugzilla.novell.com/",
              "/var/log/YaST2/"
            )
          ),
          "\n"
        )
      )

      nil
    end

    # report just some progress
    def ReportProgress(progress_s)
      progress_s = Builtins.sformat("=== %1 ===", progress_s)

      Builtins.y2milestone("%1", progress_s)
      UI.ChangeWidget(
        Id(:log_view),
        :LastLine,
        Ops.add(Ops.add("\n", progress_s), "\n")
      )

      nil
    end

    # report just a line, no modifications
    def ReportLine(line)
      Builtins.y2milestone("%1", line)
      UI.ChangeWidget(Id(:log_view), :LastLine, Ops.add(line, "\n"))

      nil
    end

    # <-- Helper Functions

    # *********************************************************************

    # --> Tests

    # checks whether the chroot binary exists
    def RunSCRSwitchTest_ChrootBinary
      test_result = FileUtils.Exists(@test_chroot_binary)

      ReportTest(
        # Test progress
        Builtins.sformat(_("Checking for %1 binary..."), @test_chroot_binary),
        test_result
      )

      test_result
    end

    # checks whether the new SCR path exists
    def RunSCRSwitchTest_ChrootPath
      test_result = FileUtils.IsDirectory(@chroot_path)

      ReportTest(
        # Test progress
        Builtins.sformat(_("Checking for chroot directory %1..."), @chroot_path),
        test_result
      )

      test_result
    end

    def RunSCRSwitchTest_ListFilesInChroot
      ret = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          Builtins.sformat("ls -1 '%1'", @chroot_path)
        )
      )

      ReportTest(
        # Test progress
        Builtins.sformat(
          _("Checking for chroot directory content (%1)..."),
          Ops.get_string(ret, "stdout", "")
        ),
        true
      )

      true
    end

    # checks whether the new SCR path exists
    def RunSCRSwitchTest_BinaryExists
      exec_file = Builtins.sformat("%1%2", @chroot_path, @test_binary_exists)
      test_result = FileUtils.Exists(exec_file)

      ReportTest(
        # Test progress
        Builtins.sformat(_("Checking for binary %1..."), exec_file),
        test_result
      )

      test_result
    end

    # tries to chroot
    def RunSCRSwitchTest_DoChroot
      test = Convert.convert(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "%1 %2 %3", # what to execute
            @test_chroot_binary, # chroot command
            @chroot_path, # where to chroot
            @test_do_chroot
          )
        ),
        :from => "any",
        :to   => "map <string, any>"
      )
      test_result = Ops.get_integer(test, "exit", 42) == 0

      ReportTest(
        # Test progress
        _("Trying to chroot..."),
        test_result
      )
      Builtins.y2milestone(
        "Debug: exit>%1<\nstdout>\n%2<\nstderr>%3<",
        Ops.get_integer(test, "exit", 0),
        Ops.get_string(test, "stdout", ""),
        Ops.get_string(test, "stderr", "")
      )

      test_result
    end

    # checks whether the y2base binary exists
    def RunSCRSwitchTest_Y2BASE
      y2basefile = Builtins.sformat("%1%2", @chroot_path, @test_y2base)
      test_result = FileUtils.Exists(y2basefile)

      ReportTest(
        # Test progress
        Builtins.sformat(
          _("Checking for %1 in %2..."),
          @test_y2base,
          @chroot_path
        ),
        test_result
      )

      test_result
    end

    def RunSCRSwitchTest_FreeSpace
      ReportProgress(_("Checking free space"))

      # Local command
      parts_cmd = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          "mount " + "| grep -v '^\\(/proc\\) on' " +
            "| sed 's/\\/.* on \\(.*\\) type .*/\\1/'"
        )
      )

      partitions = {}

      if Ops.get_integer(parts_cmd, "exit", -1) != 0
        Builtins.y2error("Cannot find out current partitions")
        # even if it is an error, we should check more
        return true
      else
        # Spash at the end or not
        inst_dir = Ops.add(
          Installation.destdir,
          Builtins.regexpmatch(Installation.destdir, "/$") ? "" : "/"
        )
        inst_dir_length = Builtins.size(inst_dir)
        Builtins.y2milestone("InstDir: '%1'", inst_dir)

        Builtins.foreach(
          Builtins.splitstring(Ops.get_string(parts_cmd, "stdout", ""), "\n")
        ) do |one_partition|
          # begin of the one_partition matches the inst_dir
          if Builtins.substring(one_partition, 0, inst_dir_length) == inst_dir
            # chrooted to the Installation::destdir
            Ops.set(
              partitions,
              Builtins.substring(
                one_partition,
                Ops.subtract(inst_dir_length, 1)
              ),
              Convert.to_integer(
                SCR.Read(path(".system.freespace"), one_partition)
              )
            )
          end
        end
      end

      Builtins.y2milestone("Partitions: %1", partitions)

      test_result = true

      Builtins.foreach(partitions) do |partition, free_space|
        this_test = true
        if Ops.less_or_equal(free_space, 0)
          test_result = false
          this_test = false
        end
        ReportTest(
          Builtins.sformat(
            # test result, %1 is replaced with the directory, e.g., /var
            # %2 is replaced with the free space in that partition, e.g., 2.8 GB
            _("Checking for free space in the %1 directory: %2"),
            partition,
            # linked to the text above (sometimes replaces the '%2')
            Ops.less_than(free_space, 0) ?
              _("Unable to find out") :
              String.FormatSize(free_space)
          ),
          this_test
        )
      end

      test_result
    end

    # tries to get all installed packages from new SCR
    def RunSCRSwitchTest_DoRPMCheck
      test = Convert.convert(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "%1 %2 %3", # what to execute
            @test_chroot_binary, # chroot command
            @chroot_path, # where to chroot
            @test_rpm
          )
        ),
        :from => "any",
        :to   => "map <string, any>"
      )
      test_result = Ops.get_integer(test, "exit", 42) == 0

      ReportTest(
        # Test progress
        _("Checking for installed RPM packages..."),
        test_result
      )
      Builtins.y2milestone(
        "Debug: exit>%1<\nstdout>\n%2<\nstderr>%3<",
        Ops.get_integer(test, "exit", 0),
        Ops.get_string(test, "stdout", ""),
        Ops.get_string(test, "stderr", "")
      )

      test_result
    end

    # checks whether the RPM is installed in SCR
    def RunSCRSwitchTest_CheckWhetherInstalled(package_name)
      test_result = nil
      ret = true
      one_rpm_installed = nil

      one_rpm_installed = Builtins.sformat(
        "%1 %2 %3",
        @test_chroot_binary,
        @chroot_path,
        Builtins.sformat(@test_one_rpm, package_name)
      )

      test = Convert.convert(
        SCR.Execute(path(".target.bash_output"), one_rpm_installed),
        :from => "any",
        :to   => "map <string, any>"
      )
      test_result = Ops.get_integer(test, "exit", -1) == 0
      ret = false if test_result != true

      ReportTest(
        # Test progress
        Builtins.sformat(
          _("Checking whether RPM package %1 is installed..."),
          package_name
        ),
        test_result
      )
      Builtins.y2milestone("Debug: %1", test)

      ret
    end

    # check which packages are required by needed packages
    def RunSCRSwitchTest_DoNeededRPMsRequire(package_name)
      test_result = nil
      ret = true

      required_packages = Convert.convert(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "%1 %2 %3",
            @test_chroot_binary,
            @chroot_path,
            Builtins.sformat(@test_requires, package_name)
          )
        ),
        :from => "any",
        :to   => "map <string, any>"
      )
      test_result = Ops.get_integer(required_packages, "exit", 42) == 0
      ret = false if !test_result

      ReportTest(
        # Test progress
        Builtins.sformat(
          _("Checking what requires RPM package %1..."),
          package_name
        ),
        test_result
      )

      # we have required objects
      if test_result
        required_packages_s = Ops.get_string(required_packages, "stdout", "")

        already_checked = []

        # check all required objects (sorted and only once)
        Builtins.foreach(
          Builtins.toset(Builtins.splitstring(required_packages_s, "\n"))
        ) do |one_require|
          next if one_require == nil || one_require == ""
          # already checked
          next if Builtins.contains(already_checked, one_require)
          # do not check again
          already_checked = Builtins.add(already_checked, one_require)
          if Builtins.regexpmatch(one_require, "[ \t]")
            one_require = Builtins.regexpsub(
              one_require,
              "^([^ \t]*)[ \t]",
              "\\1"
            )
          end
          what_provides = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "%1 %2 %3",
                @test_chroot_binary,
                @chroot_path,
                Builtins.sformat(@test_whatprovides, one_require)
              )
            ),
            :from => "any",
            :to   => "map <string, any>"
          )
          test_result = Ops.get_integer(what_provides, "exit", 42) == 0
          if !test_result
            # do not check whether required objects are installed
            # if we don't have which they are
            raise Break
            ret = false
          end
          what_provides_s = Ops.get_string(what_provides, "stdout", "")
          at_least_one = false
          # checks whether objects that provides something are installed
          Builtins.foreach(
            Builtins.toset(Builtins.splitstring(what_provides_s, "\n"))
          ) do |one_provides|
            next if one_provides == ""
            if RunSCRSwitchTest_CheckWhetherInstalled(one_provides)
              at_least_one = true
              raise Break
            else
              ret = false
            end
          end
          # none of what_provides is installed
          # or nothing provides the requierd object
          ret = false if !at_least_one
        end
      end

      ret
    end

    # checks a package, whether it is installed
    # if it is installed, whether is has installed requires
    def RunSCRSwitchTest_DoNeededRPMsCheck
      ret = true

      # check whether all needed packages are installed
      Builtins.foreach(Builtins.sort(@needed_rpm_packages)) do |package_name|
        # Test progress
        ReportProgress(
          Builtins.sformat(
            _("Running complex check on package %1..."),
            package_name
          )
        )
        # is the package installed?
        if !RunSCRSwitchTest_CheckWhetherInstalled(package_name)
          ret = false
          raise Break
        # if it is installed, check whetheris has all dependencies
        elsif !RunSCRSwitchTest_DoNeededRPMsRequire(package_name)
          ret = false
          raise Break
        end
      end

      ret
    end

    def PrintLinesFromTo(from_line, to_line)
      # start with the first line or further
      from_line = 0 if Ops.less_than(from_line, 0)

      # print all lines
      Builtins.y2milestone("Logging from: %1 to: %2", from_line, to_line)

      while Ops.less_or_equal(from_line, to_line)
        ReportLine(Ops.get(@YaST_log_lines, from_line, ""))
        from_line = Ops.add(from_line, 1)
      end

      nil
    end

    # checks the YaST log on the installed system
    def RunSCRSwitchTest_SCRChrootYaSTLog
      ret = true

      logfile = Builtins.sformat(
        "%1/%2/%3",
        Installation.destdir,
        @yast_logs,
        @yast_logfile
      )
      Builtins.y2milestone("Checking file %1", logfile)

      ReportProgress(
        Builtins.sformat(_("Checking YaST log file %1..."), logfile)
      )

      _YaST_log = Convert.to_string(WFM.Read(path(".local.string"), logfile))

      current_line = -1

      # cannot open YaST log
      if _YaST_log == nil
        ret = false
        ReportTest(_("Opening file..."), ret) 
        # checking YaST log
      else
        @YaST_log_lines = Builtins.splitstring(_YaST_log, "\n")

        Builtins.foreach(@YaST_log_lines) do |one_line|
          current_line = Ops.add(current_line, 1)
          # SCR has died, printing the last 15 lines
          if Builtins.regexpmatch(one_line, " Finished YaST.* component ")
            ReportLine(
              _("SCR process has died, printing the last log lines...")
            )
            start_line = Ops.subtract(current_line, 15)
            PrintLinesFromTo(start_line, current_line)

            ret = false
            raise Break 
            # YaST got killed
          elsif Builtins.regexpmatch(one_line, " got signal ")
            # Print just the last line
            ReportLine(_("YaST process got killed."))
            PrintLinesFromTo(current_line, current_line)
            ret = false
            raise Break
          end
        end

        @YaST_log_lines = []

        ReportTest(_("Checking YaST log..."), ret)
      end

      ret
    end

    # main test
    def RunSCRSwitchTests
      # Test progress
      ReportProgress(_("System Checking"))

      return false if !RunSCRSwitchTest_ChrootBinary()
      return false if !RunSCRSwitchTest_ChrootPath()
      return false if !RunSCRSwitchTest_ListFilesInChroot()
      return false if !RunSCRSwitchTest_BinaryExists()
      return false if !RunSCRSwitchTest_DoChroot()
      return false if !RunSCRSwitchTest_Y2BASE()
      return false if !RunSCRSwitchTest_FreeSpace()
      return false if !RunSCRSwitchTest_DoRPMCheck()

      # checking all mandatory packages
      return false if !RunSCRSwitchTest_DoNeededRPMsCheck()

      return false if !RunSCRSwitchTest_SCRChrootYaSTLog()

      # Add new checks here...

      true
    end

    # <-- Tests

    # *********************************************************************

    # --> Special Functions

    # Copy YaST logs from the just installed system to inst-sys
    def CopyY2logsFromSCRToInstSys
      # where SCR logs are stored now
      scr_logs_directory = Builtins.sformat("%1%2", @chroot_path, @yast_logs)
      # where to copy them
      copy_to_directory = Builtins.sformat("%1InstalledSystemLogs", @yast_logs)

      command = Builtins.sformat(
        "cp -avr '%1' '%2'",
        scr_logs_directory,
        copy_to_directory
      )

      Builtins.y2milestone(
        "Copying YaST logs from the system to inst-sys: %1 -> %2",
        command,
        WFM.Execute(path(".local.bash_output"), command)
      )

      nil
    end

    def FindSCRPID
      cmd = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          "LC_ALL=C /bin/ps a | grep 'scr stdio' | grep -v 'grep'"
        )
      )

      if Ops.get_integer(cmd, "exit", -1) != 0
        Builtins.y2error("Cannot find scr process")
        return -1
      end

      outlines = Builtins.filter(
        Builtins.splitstring(Ops.get_string(cmd, "stdout", ""), "\n")
      ) { |one_outline| one_outline != "" }
      outline = Ops.get(outlines, Ops.subtract(Builtins.size(outlines), 1), "")

      if !Builtins.regexpmatch(outline, "^[[:digit:]]+")
        Builtins.y2error("No PID in %1", outline)
        return -1
      end

      outline = Builtins.regexpsub(
        outline,
        "^([[:digit:]]+)[[:space:]].*",
        "\\1"
      )

      ret = Builtins.tointeger(outline)
      Builtins.y2milestone("SCR PID: %1", ret)

      ret
    end

    # This is potentially insecure
    def SwitchY2Debug(_PID)
      if _PID == nil
        Builtins.y2error("PID cannot be: %1", _PID)
        return
      end

      cmd = Builtins.sformat("kill -s USR1 %1", _PID)

      Builtins.y2milestone(
        "Adjusting Y2DEBUG >%1<: %2",
        cmd,
        WFM.Execute(path(".local.bash_output"), cmd)
      )

      nil
    end

    # <-- Special Functions

    # *********************************************************************

    # Function debugs why the SCR switch failed and reports
    # it to user.
    #
    # @param string failed_chroot_chroot
    def RunSCRSwitchDebugger(failed_chroot_path)
      if failed_chroot_path == nil
        Builtins.y2error("Chroot path not defined!")
        # popup error
        Popup.Error(_("Unknown chroot path. The debugger cannot continue."))
        return
      end
      # will be used for all chroot calls later
      @chroot_path = failed_chroot_path

      # if any SCR exists
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen(
        Ops.add(Ops.add("chroot=", @new_SCR_path), ":scr"),
        false
      )
      if Ops.less_than(new_SCR, 0)
        Builtins.y2error("Cannot conenct to SCR %1", @new_SCR_path)
        Popup.Error(
          _("Connecting to the inst-sys failed. Debugger cannot continue.")
        )
        return
      end
      # Set the new SCR as a defalt one
      WFM.SCRSetDefault(new_SCR)

      # Copy all YaST log files from SCR to Inst-Sys
      # before SCR test
      CopyY2logsFromSCRToInstSys()

      Builtins.y2milestone("* ---------- Debugger Start ---------- *")

      UI.OpenDialog(SCRSwitchDialog())
      RunSCRSwitchTests()
      UI.ReplaceWidget(Id(:dialog_rp), PushButton(Id(:ok), Label.OKButton))
      ret = nil
      while ret != :ok
        ret = UI.UserInput
      end
      UI.CloseDialog

      Builtins.y2milestone("* ---------- Debugger Finish ---------- *")

      # Close the SCR created for testing
      WFM.SCRClose(new_SCR)
      # Set the previous one as the default
      WFM.SCRSetDefault(old_SCR)

      # Copy all YaST log files from SCR to Inst-Sys
      # after SCR tests
      CopyY2logsFromSCRToInstSys()

      nil
    end
  end
end

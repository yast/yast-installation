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
#	Vendor.ycp
#
# Module:
#	Vendor
#
# Summary:
#	provide vendor/driver update disk functions
#
# $Id$
#
# Author:
#	Klaus Kaempf <kkaempf@suse.de>
#
require "yast"

module Yast
  class VendorClass < Module
    def main
      Yast.import "Installation"
      Yast.import "Directory"
      Yast.import "String"
    end

    # --------------------------------------------------------------
    # driver update ?!

    # DriverUpdate
    # copy /update/* to target:/tmp/update/
    # !! can only be called in inst_finish !!

    def DriverUpdate1
      updatefiles = Convert.convert(
        WFM.Read(path(".local.dir"), ["/update", []]),
        :from => "any",
        :to   => "list <string>"
      )
      if Ops.less_or_equal(Builtins.size(updatefiles), 0)
        Builtins.y2milestone("No files in /update, skipping driver update...")
        return
      end

      Builtins.y2milestone("Extracting driver update...")

      # clean up, just in case
      SCR.Execute(path(".target.bash"), "/usr/bin/rm -rf /tmp/update")

      # copy log file
      WFM.Execute(
        path(".local.bash"),
        Ops.add(
          Ops.add(
            "l=/var/log/driverupdate.log ; [ -f $l ] && /bin/cat $l " + ">> '",
            String.Quote(Installation.destdir)
          ),
          "$l'"
        )
      )

      # copy all update files from inst-sys to installed system
      WFM.Execute(
        path(".local.bash"),
        Ops.add(
          Ops.add(
            "/bin/cp -a /update " + "'",
            String.Quote(Installation.destdir)
          ),
          "/tmp/update'"
        )
      )

      logfile = "/var/log/zypp/history"

      runcmd = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            Ops.add(
                              Ops.add(
                                Ops.add(
                                  Ops.add(
                                    Ops.add(
                                      "cd /; \n" +
                                        "for i in /tmp/update/[0-9]*/install ; do \n" +
                                        # Logging extracting the driver update
                                        "    echo \"# Installing Driver Update from $i\">>",
                                      logfile
                                    ),
                                    "; \n"
                                  ),
                                  "    TMPFILE=\"/tmp/update/${i}rpm_install_tmpfile\"; \n"
                                ),
                                "    [ -x \"/bin/mktemp\" ] && TMPFILE=`/bin/mktemp`; \n"
                              ),
                              # Extracting the driver update archives
                              "    cd $i; \n"
                            ),
                            "    [ -f \"update.tar.gz\" ] && /bin/tar -zxf \"update.tar.gz\"; \n"
                          ),
                          "    [ -f \"update.tgz\" ] && /bin/tar -zxf \"update.tgz\"; \n"
                        ),
                        # Installing all extracted RPMs
                        "    rpm -Uv --force *.rpm 1>>$TMPFILE 2>>$TMPFILE; \n"
                      ),
                      # Logging errors
                      "    [ -s \"$TMPFILE\" ] && echo \"# Additional rpm output:\">>"
                    ),
                    logfile
                  ),
                  " && sed 's/^\\(.*\\)/# \\1/' $TMPFILE>>"
                ),
                logfile
              ),
              "; \n"
            ),
            "    rm -rf $TMPFILE; \n"
          ),
          # Running update.post script
          "    [ -f \"update.post\" ] && /bin/chmod +x \"update.post\" && \"./update.post\" \"$i\"; \n"
        ),
        "done;"
      )

      Builtins.y2milestone(
        "Calling:\n" +
          "---------------------------------------------------------\n" +
          "%1\n" +
          "---------------------------------------------------------",
        runcmd
      )

      # unpack update files and run update.post scripts
      # via SCR chrooted into the installed system
      cmd = Convert.to_map(SCR.Execute(path(".target.bash_output"), runcmd))
      Builtins.y2milestone("Driver Update deployment returned: %1", cmd)

      nil
    end

    def DriverUpdate2
      updatefiles = Convert.convert(
        WFM.Read(path(".local.dir"), ["/update", []]),
        :from => "any",
        :to   => "list <string>"
      )
      return if Ops.less_or_equal(Builtins.size(updatefiles), 0)

      # run update.post2 scripts
      SCR.Execute(
        path(".target.bash"),
        "cd / ; " + "for i in /tmp/update/[0-9]*/install ; do " +
          "    [ -f \"$i/update.post2\" ] && /bin/chmod +x \"$i/update.post2\" && \"$i/update.post2\" \"$i\" ; " + "done"
      )

      # remove driver update dir
      SCR.Execute(path(".target.bash"), "/usr/bin/rm -rf /tmp/update")

      nil
    end

    publish :function => :DriverUpdate1, :type => "void ()"
    publish :function => :DriverUpdate2, :type => "void ()"
  end

  Vendor = VendorClass.new
  Vendor.main
end

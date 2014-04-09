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
#  copy_logs_finish.ycp
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
  class CopyLogsFinishClient < Client
    def main
      Yast.import "UI"

      textdomain "installation"

      Yast.import "Directory"
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

      Builtins.y2milestone("starting copy_logs_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Copying log files to installed system..."
          ),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        @log_files = Convert.convert(
          WFM.Read(path(".local.dir"), Directory.logdir),
          :from => "any",
          :to   => "list <string>"
        )

        Builtins.foreach(@log_files) do |file|
          if file == "y2log" || Builtins.regexpmatch(file, "^y2log-[0-9]+$")
            # Prepare y2log, y2log-* for log rotation

            target_no = 1

            if Ops.greater_than(Builtins.size(file), Builtins.size("y2log-"))
              target_no = Ops.add(
                1,
                Builtins.tointeger(
                  Builtins.substring(file, Builtins.size("y2log-"), 5)
                )
              )
            end

            target_basename = Builtins.sformat("y2log-%1", target_no)
            InjectRenamedFile(Directory.logdir, file, target_basename)

            compress_cmd = Builtins.sformat(
              "gzip %1/%2/%3",
              Installation.destdir,
              Directory.logdir,
              target_basename
            )
            WFM.Execute(path(".local.bash"), compress_cmd)
          elsif Builtins.regexpmatch(file, "^y2log-[0-9]+\\.gz$")
            target_no = Ops.add(
              1,
              Builtins.tointeger(
                Builtins.regexpsub(file, "y2log-([0-9]+)\\.gz", "\\1")
              )
            )
            InjectRenamedFile(
              Directory.logdir,
              file,
              Builtins.sformat("y2log-%1.gz", target_no)
            )
          elsif file == "zypp.log"
            # Save zypp.log from the inst-sys
            InjectRenamedFile(Directory.logdir, file, "zypp.log-1") # not y2log, y2log-*
          else
            InjectFile(Ops.add(Ops.add(Directory.logdir, "/"), file))
          end
        end

        WFM.Execute(
          path(".local.bash"),
          "/bin/cp /var/log/pbl.log '#{Installation.destdir}/#{Directory.logdir}/pbl-instsys.log'"
        )
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("copy_logs_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::CopyLogsFinishClient.new.main

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2015 Novell, Inc. All Rights Reserved.
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

require "yast"

require "installation/finish_client"

module Installation
  class CopyLogsFinish < ::Installation::FinishClient
    include Yast::I18n

    def initialize
      textdomain "installation"

      Yast.import "Directory"
      Yast.include self, "installation/misc.rb"
    end

    def steps
      1
    end

    def title
      _("Copying log files to installed system...")
    end

    def modes
      [:installation, :live_installation, :update, :autoinst]
    end

    def write
      log_files = Yast::WFM.Read(Yast::Path.new(".local.dir"), Yast::Directory.logdir)

      log_files.each do |file|
        log.debug "Processing file #{file}"

        if file == "y2log" || file =~ /\Ay2log-\d+\z/
          # Prepare y2log, y2log-* for log rotation
          target_no = 1

          if file != "y2log"
            prefix_size = "y2log-".size
            target_no = file[prefix_size..-1].to_i + 1
          end

          target_basename = "y2log-#{target_no}"
          InjectRenamedFile(Yast::Directory.logdir, file, target_basename)

          target_path = ::File.join(
            Yast::Installation.destdir,
            Yast::Directory.logdir,
            target_basename
          )
          compress_cmd = "gzip #{target_path}"
          log.debug "Compress command: #{compress_cmd}"
          Yast::WFM.Execute(Yast::Path.new(".local.bash"), compress_cmd)
        elsif file =~ /\Ay2log-\d+\.gz\z/
          target_no = file[/y2log-(\d+)/, 1].to_i + 1
          InjectRenamedFile(
            Yast::Directory.logdir,
            file,
            "y2log-#{target_no}"
          )
        elsif file == "zypp.log"
          # Save zypp.log from the inst-sys
          InjectRenamedFile(Yast::Directory.logdir, file, "zypp.log-1") # not y2log, y2log-*
        else
          InjectFile(::File.join(Yast::Directory.logdir, file))
        end
      end

      copy_cmd = "/bin/cp /var/log/pbl.log '#{Yast::Installation.destdir}/#{Yast::Directory.logdir}/pbl-instsys.log'"
      log.debug "Copy command: #{copy_cmd}"
      Yast::WFM.Execute(Yast::Path.new(".local.bash"), copy_cmd)

      nil
    end
  end
end

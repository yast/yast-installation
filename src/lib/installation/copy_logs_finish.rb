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

    LOCAL_BASH = Yast::Path.new(".local.bash")

    def initialize
      textdomain "installation"

      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "ProductFeatures"
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

    PREFIX_SIZE = "y2log-".size
    STORAGE_DUMP_DIR = "storage-inst".freeze

    def write
      log_files = Yast::WFM.Read(Yast::Path.new(".local.dir"), Yast::Directory.logdir)

      log_files.each do |file|
        log.debug "Processing file #{file}"

        case file
        when "y2log", /\Ay2log-\d+\z/
          # Prepare y2log, y2log-* for log rotation
          target_no = 1

          target_no = file[PREFIX_SIZE..-1].to_i + 1 if file != "y2log"

          target_basename = "y2log-#{target_no}"
          copy_log_to_target(file, target_basename)

          target_path = ::File.join(
            Yast::Installation.destdir,
            Yast::Directory.logdir,
            target_basename
          )
          # call gzip with -f to avoid stuck during race condition when log
          # rotator also gzip file and gzip then wait for input (bnc#897091)
          shell_cmd("/usr/bin/gzip -f '#{target_path}'")
        when /\Ay2log-\d+\.gz\z/
          target_no = file[/y2log-(\d+)/, 1].to_i + 1
          copy_log_to_target(file, "y2log-#{target_no}.gz")
        when "zypp.log"
          # Save zypp.log from the inst-sys
          copy_log_to_target(file, "zypp.log-1") # not y2log, y2log-*
        when "pbl.log"
          copy_log_to_target("pbl.log", "pbl-instsys.log")
        when STORAGE_DUMP_DIR
          copy_storage_inst_subdir
        else
          copy_log_to_target(file)
        end
      end

      # Saving y2logs
      WFM.CallFunction("save_y2logs")

      nil
    end

  private

    def copy_log_to_target(src_file, dest_file = src_file)
      shell_cmd("/bin/cp '#{src_dir}/#{src_file}' '#{dest_dir}/#{dest_file}'")
    end

    def copy_storage_inst_subdir
      return if dest_dir == "/"
      shell_cmd("/bin/rm -rf '#{dest_dir}/#{STORAGE_DUMP_DIR}'")
      shell_cmd("/bin/cp -r '#{src_dir}/#{STORAGE_DUMP_DIR}' '#{dest_dir}/#{STORAGE_DUMP_DIR}'")
    end

    def src_dir
      Yast::Directory.logdir
    end

    def dest_dir
      File.join(Yast::Installation.destdir, Yast::Directory.logdir)
    end

    def shell_cmd(cmd)
      log.info("Executing #{cmd}")
      Yast::WFM.Execute(LOCAL_BASH, cmd)
    end
  end
end

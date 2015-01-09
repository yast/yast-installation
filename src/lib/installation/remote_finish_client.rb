# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2014 SUSE Linux GmbH. All Rights Reserved.
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
# ------------------------------------------------------------------------------

require "yast"

module Installation

  # Step of base installation finish for remote administration (VNC)
  class RemoteFinishClient
    include Yast::Logger
    include Yast::I18n

    def initialize
      Yast.import "Linuxrc"
      Yast.import "Remote"
      textdomain "installation"
    end

    # Executes the function passed as a first argument, to be called by
    # WMF.CallFunction
    def run(*args)
      ret = nil
      if args.empty?
        func = ""
      else
        func = args.first.to_s
      end

      log.info "starting remote_finish"
      log.debug "func=#{func}"

      case func
      when "Info"
        ret = {
          "steps" => 1,
          "title" => title,
          "when"  => modes
        }
      when "Write"
        enable_remote
      else
        log.error "unknown function: #{func}"
      end

      log.debug "ret=#{ret}"
      log.info "remote_finish finished"
      ret
    end

    # Text to display
    #
    # @return String
    def title
      _("Enabling remote administration...")
    end

    # Modes in which #enable_remote should be called
    #
    # @return Array<Symbol>
    def modes
      Yast::Linuxrc.vnc ? [:installation, :autoinst] : []
    end

    # Enables remote access
    def enable_remote
      Yast::Remote.Enable
      Yast::Remote.Write
    end
  end
end

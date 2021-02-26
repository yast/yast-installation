# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "y2firewall/firewalld"
require "installation/security_settings"
require "installation/finish_client"

Yast.import "Mode"
Yast.import "SignatureCheckDialogs"

module Installation
  module Clients
    # This is a step of base installation finish and it is responsible of write
    # the firewall proposal configuration for installation and autoinstallation
    # modes.
    class SecurityFinish < ::Installation::FinishClient
      include Yast::I18n
      include Yast::Logger

      # Installation::SecuritySettings
      attr_accessor :settings
      # Y2Firewall::Firewalld instance
      attr_accessor :firewalld

      # Constuctor
      def initialize
        textdomain "installation"
        @settings = ::Installation::SecuritySettings.instance
        @firewalld = Y2Firewall::Firewalld.instance
      end

      def title
        _("Writing Security Configuration...")
      end

      def modes
        [:installation, :autoinst, :update]
      end

      def write
        write_firewall

        Yast::SCR.Write(
          Yast::Path.new(".sysconfig.security.CHECK_SIGNATURES"),
          Yast::SignatureCheckDialogs.CheckSignatures
        )

        # ensure we have correct ca certificates
        if Yast::Mode.update
          res = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"),
            "/usr/sbin/update-ca-certificates")
          log.info("updating ca certificates result: #{res}")
        end

        write_polkit

        # workaround missing capabilities if we use deployment from images
        # as tarballs which is used for images for not support it (bnc#889489)
        # do nothing if capabilities are properly set
        res = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"),
          "/usr/bin/chkstat --system --set")
        log.info("updating capabilities: #{res}")

        # in autoinstallation write security profile here
        Yast::Security.Write if Yast::Mode.autoinst

        # Write down selinux configuration
        settings.selinux_config.save

        true
      end

    private

      def write_polkit
        # Do not write polkit privs during update (bsc#1120720)
        return if Yast::Mode.update

        polkit_default_privs = @settings.polkit_default_privileges
        # exit if there is no config to write
        return if [nil, ""].include?(polkit_default_privs)

        log.info "Writing #{polkit_default_privs} to POLKIT_DEFAULT_PRIVS"
        Yast::SCR.Write(
          Yast::Path.new(".sysconfig.security.POLKIT_DEFAULT_PRIVS"),
          polkit_default_privs
        )
        # BNC #440182
        # Flush the SCR cache before calling the script
        Yast::SCR.Write(Yast::Path.new(".sysconfig.security"), nil)

        ret2 = Yast::SCR.Execute(
          Yast::Path.new(".target.bash_output"),
          # check whether it exists
          # give some feedback
          # It's dozens of lines...
          "test -x /sbin/set_polkit_default_privs && " \
            "echo /sbin/set_polkit_default_privs && " \
            "/sbin/set_polkit_default_privs | wc -l && " \
            "echo 'Done'"
        )
        log.info "Command returned: #{ret2}"
      end

      # Modifies the configuration of the firewall according to the current
      # settings
      def configure_firewall
        configure_firewall_service
        configure_ssh
        configure_vnc
      end

      # Convenience method to enable / disable the firewalld service depending
      # on the proposal settings
      def configure_firewall_service
        # and also only installation, not upgrade one. NOTE: installation mode include auto
        return unless Yast::Mode.installation

        @settings.enable_firewall ? @firewalld.enable! : @firewalld.disable!
      end

      # Convenience method to open the ssh ports in firewalld depending on the
      # proposal settings
      def configure_ssh
        if @settings.open_ssh
          @firewalld.api.add_service(@settings.default_zone, "ssh")
        else
          @firewalld.api.remove_service(@settings.default_zone, "ssh")
        end
      end

      # Convenience method to open the vnc ports in firewalld depending on the
      # proposal settings
      def configure_vnc
        return unless @settings.open_vnc

        if @firewalld.api.service_supported?("tigervnc")
          @firewalld.api.add_service(@settings.default_zone, "tigervnc")
          @firewalld.api.add_service(@settings.default_zone, "tigervnc-https")
        else
          log.error "tigervnc service definition is not available"
        end
      end

      def write_firewall
        # write firewall and ssh only during fresh install
        return if Yast::Mode.update

        if Yast::Mode.auto
          # Lazy load of firewall auto client as it depends on auto installation
          require "y2firewall/clients/auto"

          # If the profile is missing then firewall section is not present at all.
          # The firewall will be configured according to product proposals then.
          if Y2Firewall::Clients::Auto.profile
            log.info("Firewall: running configuration according to the AY profile")
            return Y2Firewall::Clients::Auto.new.write
          end
        end

        Yast::Service.Enable("sshd") if @settings.enable_sshd
        configure_firewall if @firewalld.installed?
      end
    end
  end
end

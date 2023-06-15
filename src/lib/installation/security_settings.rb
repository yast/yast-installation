# coding: utf-8
# Copyright (c) [2017-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2users"
require "y2security/lsm"

module Installation
  # Class that stores the security proposal settings during installation.
  class SecuritySettings
    include Yast::Logger
    include Yast::I18n

    # [Boolean] Whether the firewalld service will be enable
    attr_accessor :enable_firewall
    # [Boolean] Whether the sshd service will be enable
    attr_accessor :enable_sshd
    # [Boolean] Whether the ssh port will be opened
    attr_accessor :open_ssh
    # [Boolean] Whether the vnc port will be opened
    attr_accessor :open_vnc
    # [String] Name of the default zone where perform the changes
    attr_accessor :default_zone
    # [String, nil] Setting for policy kit default privileges
    # For more info see /etc/sysconfig/security#POLKIT_DEFAULT_PRIVS
    attr_accessor :polkit_default_privileges

    # Constructor
    def initialize
      textdomain "installation"
      Yast.import "PackagesProposal"
      Yast.import "ProductFeatures"
      Yast.import "Linuxrc"

      load_features
      enable_firewall! if @enable_firewall
      enable_sshd! if wanted_enable_sshd?
      open_ssh! if wanted_open_ssh?
      open_vnc! if wanted_open_vnc?
      propose_lsm_config
      # FIXME: obtain from Y2Firewall::Firewalld, control file or allow to
      # chose a different one in the proposal
      @default_zone = "public"
    end

    # Load the default values defined in the control file
    def load_features
      load_feature(:enable_firewall, :enable_firewall)
      load_feature(:firewall_enable_ssh, :open_ssh)
      load_feature(:enable_sshd, :enable_sshd)
      load_feature(:polkit_default_privs, :polkit_default_privileges)
    end

    # When Linux Security Module is declared as configurable and there is no Module selected yet
    # it will select the desired LSM and the needed patterns for it accordingly
    def propose_lsm_config
      return unless lsm_config.configurable?
      return if lsm_config.selected

      lsm_config.propose_default
      # It will be set even if the proposal is not shown (e.g. configurable but not selectable)
      Yast::PackagesProposal.SetResolvables("LSM", :pattern, lsm_config.needed_patterns)
    end

    # Make a proposal for the security settings:
    #
    # If only public key authentication is configured, and no root password is set,
    # open the SSH port and enable SSHD so at least SSH access can be used.
    #
    # This should be called AFTER the user was prompted for the root password, e.g.
    # when the security proposal is made during installation.
    def propose
      log.info("Making security settings proposal")
      return unless only_public_key_auth?

      log.info("Only public key auth")
      open_ssh! unless @open_ssh
      enable_sshd! unless @enable_sshd
    end

    # Services

    # Add the firewall package to be installed and sets the firewalld service
    # to be enabled
    def enable_firewall!
      Yast::PackagesProposal.AddResolvables("firewall", :package, ["firewalld"])

      log.info "Enabling firewall"
      self.enable_firewall = true
    end

    # Remove the firewalld package from being installed and sets the firewalld
    # service to be disabled
    def disable_firewall!
      Yast::PackagesProposal.RemoveResolvables("firewall", :package, ["firewalld"])
      log.info "Disabling firewall"
      self.enable_firewall = false
    end

    # Add the openssh package to be installed and sets the sshd service
    # to be enabled
    def enable_sshd!
      Yast::PackagesProposal.AddResolvables("firewall", :package, ["openssh"])
      log.info "Enabling SSHD"
      self.enable_sshd = true
    end

    # Remove the openssh package from being installed and sets the sshd service
    # to be disabled
    def disable_sshd!
      Yast::PackagesProposal.RemoveResolvables("firewall", :package, ["openssh"])
      log.info "Disabling SSHD"
      self.enable_sshd = false
    end

    # Set the ssh port to be opened
    def open_ssh!
      log.info "Opening SSH port"
      self.open_ssh = true
    end

    # Set the ssh port to be closed
    def close_ssh!
      log.info "Closing SSH port"
      self.open_ssh = false
    end

    # Set the vnc port to be opened
    def open_vnc!
      log.info "Opening VNC port"
      self.open_vnc = true
    end

    # Set the vnc port to be closed
    def close_vnc!
      log.info "Closing VNC port"
      self.open_vnc = false
    end

    # Return whether the current settings could be a problem for the user to
    # login
    #
    # @return [Boolean] true if the root user uses only public key
    #   authentication and the system is not accesible through ssh
    def access_problem?
      # public key is not the only way
      return false unless only_public_key_auth?

      # without running sshd it is useless
      return true unless @enable_sshd

      # firewall is up and port for ssh is not open
      @enable_firewall && !@open_ssh
    end

    def human_polkit_privileges
      {
        ""            => _("Default"),
        # TRANSLATORS: restrictive in sense the most restrictive policy
        "restrictive" => _("Restrictive"),
        "standard"    => _("Standard"),
        # TRANSLATORS: easy in sense the least restrictive policy
        "easy"        => _("Easy")
      }
    end

    # @return [Y2Security::LSM::Config] the LSM config handler
    def lsm_config
      Y2Security::LSM::Config.instance
    end

  private

    def load_feature(feature, to, source: global_section)
      value = Yast::Ops.get(source, feature.to_s)
      public_send("#{to}=", value) unless value.nil?
    end

    def global_section
      Yast::ProductFeatures.GetSection("globals")
    end

    def wanted_enable_sshd?
      Yast::Linuxrc.usessh || @enable_sshd
    end

    def wanted_open_ssh?
      Yast::Linuxrc.usessh || @open_ssh
    end

    def wanted_open_vnc?
      Yast::Linuxrc.vnc
    end

    # Determines whether only public key authentication is supported.
    #
    # Do not call this prematurely before the user was even prompted for a root password;
    # in particular, do not call this from the constructor of this class.
    #
    # @note If the root user does not have a password, we assume that we will use a public
    #   key in order to log into the system. In such a case, we need to enable the SSH
    #   service (including opening the port).
    def only_public_key_auth?
      if root_user.nil?
        log.warn("No root user created yet; can't check root password!")
        return false
      end

      password = root_user.password_content || ""
      password.empty?
    end

    # Root user from the target config
    #
    # @return [Y2Users::User, nil]
    def root_user
      config = Y2Users::ConfigManager.instance.target

      return nil unless config

      config.users.root
    end

    class << self
      def run
        instance.run
      end

      # Singleton instance
      def instance
        create_instance unless @instance
        @instance
      end

      # Enforce a new clean instance
      def create_instance
        @instance = new
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end
  end
end

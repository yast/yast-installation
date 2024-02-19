# ------------------------------------------------------------------------------
# Copyright (c) 2024 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

require "cwm"
require "installation/console/menu_plugin"
require "y2storage"
require "y2storage/storage_env"

Yast.import "ProductFeatures"
Yast.import "Arch"
Yast.import "Report"

module Installation
  module Console
    module Plugins
      # define a checkbox for enabling LUKS2 and systemd_boot support in the installer
      class LUKS2SystemdBootCheckBox < CWM::CustomWidget
        include Yast::Logger

        def initialize
          super
          textdomain "installation"
        end

        def contents
          CheckBoxFrame(
            Id(:frame),
            _("Set systemd-bootloader and LUKS2 Encryption while evaluating the propsal"),
            false,
            HBox(
              HSpacing(2),
              # TRANSLATORS: text entry, please keep it short
              Password(Id(:pw1), _("&Password for LUKS2 Encryption")),
              HSpacing(8),
              # text entry
              Password(Id(:pw2), _("Re&type LUKS2 Encryption Password"))
            )
          )
        end

        def validate
          return true unless Yast::UI.QueryWidget(Id(:frame), :Value)

          if Yast::UI.QueryWidget(Id(:pw1), :Value) == ""
            Yast::Report.Error(_("The password must not be empty."))
            Yast::UI.SetFocus(Id(:pw1))
            return false
          end
          if Yast::UI.QueryWidget(Id(:pw1), :Value) == Yast::UI.QueryWidget(Id(:pw2), :Value)
            return true
          end

          Yast::Report.Error(_(
            "'Password' and 'Retype password'\ndo not match. Retype the password."
          ))
          Yast::UI.SetFocus(Id(:pw1))
          false
        end

        # set the initial status
        def init
          proposal_section = Yast::ProductFeatures.GetFeature("partitioning", "proposal")
          encryption = proposal_section.nil? ? nil : proposal_section["encryption"]
          password = if !encryption.nil? && !encryption["password"].nil?
            encryption["password"]
          else
            ""
          end

          Yast::UI.ChangeWidget(Id(:frame), :Value, !password.empty?)
          Yast::UI.ChangeWidget(Id(:pw2), :Value, password)
          Yast::UI.ChangeWidget(Id(:pw1), :Value, password)
        end

        def store
          proposal_section = Yast::ProductFeatures.GetFeature("partitioning", "proposal")

          if Yast::UI.QueryWidget(Id(:frame), :Value)
            # pbkdf2 is default because it can be used by grub2 too
            proposal_section["encryption"] = { "type" => "luks2", "pbkdf" => "argon2id",
                                              "password" => Yast::UI.QueryWidget(Id(:pw1), :Value) }
            ENV["YAST_LUKS2_AVAILABLE"] = "1"
            Yast::ProductFeatures.SetStringFeature("globals", "prefered_bootloader", "systemd-boot")
          else
            proposal_section["encryption"] = {}
            Yast::ProductFeatures.SetStringFeature("globals", "prefered_bootloader", "")
          end
          Yast::ProductFeatures::SetFeature("partitioning", "proposal", proposal_section)
        end

        def help
          # TRANSLATORS: help text for the checkbox enabling LUKS2 and systemd_boot
          _("<p>You can set LUKS2 encryption and systemd boot installation.</p>")
        end
      end

      # define the plugin
      class LUKS2SystemdBootCheckBoxPlugin < MenuPlugin
        def widget
          if Yast::ProductFeatures.GetBooleanFeature("globals", "enable_systemd_boot") &&
              Y2Storage::Arch.new.efiboot? &&
              (Yast::Arch.x86_64 || Yast::Arch.aarch64) # only these architectures are supported
            LUKS2SystemdBootCheckBox.new
          else
            CWM::Empty.new("empty")
          end
        end

        # Set after the availability of LUKS2 encryption checkbox
        def order
          3000
        end
      end
    end
  end
end

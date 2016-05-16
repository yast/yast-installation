# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "ui/installation_dialog"
require "installation/ssh_importer"

module Yast
  class SshImportDialog < ::UI::InstallationDialog
    def initialize
      super

      Yast.import "UI"
      Yast.import "Label"

      textdomain "installation"
    end

    # Event callback for the 'ok' button
    def next_handler
      partition = UI.QueryWidget(Id(:device), :Value)
      partition = nil if partition == :none
      copy_config = UI.QueryWidget(Id(:copy_config), :Value)
      log.info "SshImportDialog partition => #{partition} copy_config => #{copy_config}"
      importer.device = partition
      importer.copy_config = copy_config
      super
    end

  private

    def importer
      @importer ||= ::Installation::SshImporter.instance
    end

    def partitions
      @partitions ||= importer.configurations
    end

    def device
      @device ||= importer.device
    end

    def copy_config
      @copy_config ||= importer.copy_config
    end

    def dialog_content
      HSquash(
        VBox(
          Left(Label(_("System to Import SSH Keys from"))),
          partitions_list_widget,
          VSpacing(1),
          Left(copy_config_widget)
        )
      )
    end

    def dialog_title
      _("Import SSH Keys and Configuration")
    end

    def help_text
      _(
        "<p>Choose an existing Linux installation to reuse the keys of its SSH " \
        "server. The key files found in /etc/ssh will be copied to the new " \
        "system being installed.</p>" \
        "<p>Check <b>Copy Whole SSH Configuration</b> to also copy other files " \
        "found in /etc/ssh, in addition to the keys.</p>"
      )
    end

    def partitions_list_widget
      sorted_partitions = partitions.to_a.sort_by(&:first)
      part_widgets = sorted_partitions.map do |device, partition|
        Left(partition_widget(device, partition))
      end

      RadioButtonGroup(
        Id(:device),
        VBox(
          # TRANSLATORS: option to select no partition for SSH keys import
          Left(RadioButton(Id(:none), _("None"), device.nil?)),
          *part_widgets
        )
      )
    end

    def partition_widget(dev, partition)
      strings = { system_name: partition.system_name, device: dev }
      # TRANSLATORS: %{system_name} is a string like "openSUSE 13.2", %{device}
      # is a string like /dev/sda1
      name = _("%{system_name} at %{device}") % strings
      RadioButton(Id(dev), name, device == dev)
    end

    def copy_config_widget
      CheckBox(Id(:copy_config), _("Copy Whole SSH Configuration"), copy_config)
    end
  end
end

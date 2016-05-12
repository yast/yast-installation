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
require "ui/dialog"
require "installation/ssh_config"

module Yast
  class SshImportDialog < ::UI::Dialog
    def initialize(device, copy_config)
      super()

      Yast.import "UI"
      Yast.import "Label"

      textdomain "installation"

      @device = device
      @copy_config = copy_config
    end

    # Event callback for the 'ok' button
    def ok_handler
      partition = UI.QueryWidget(Id(:device), :Value)
      partition = nil if partition == :none
      copy_config = UI.QueryWidget(Id(:copy_config), :Value)
      finish_dialog(device: partition, copy_config: copy_config)
    end

  private

    attr_reader :device, :copy_config

    def partitions
      @partitions ||= ::Installation::SshConfig.all.reject { |c| c.keys.empty? }
    end

    def dialog_content
      VBox(
        Heading(_("System to Import SSH Keys from")),
        HBox(
          HStretch(),
          VBox(
            partitions_list_widget,
            VSpacing(0.5),
            Left(copy_config_widget)
          ),
          HStretch()
        ),
        VSpacing(0.5),
        HBox(
          PushButton(Id(:ok), Opt(:default), Label.OKButton),
          PushButton(Id(:cancel), Label.CancelButton)
        )
      )
    end

    def dialog_options
      Opt(:decorated)
    end

    def partitions_list_widget
      part_widgets = partitions.map do |partition|
        Left(partition_widget(partition))
      end

      RadioButtonGroup(
        Id(:device),
        VBox(
          # TRANSLATORS: option to select no partition for SSH keys import
          Left(RadioButton(Id(:none), _("None"), @device.nil?)),
          *part_widgets
        )
      )
    end

    def partition_widget(partition)
      dev = partition.device
      strings = {system_name: partition.system_name, device: dev}
      # TRANSLATORS: system_name is a string like "openSUSE 13.2", device
      # is a string like /dev/sda1
      name = _("%{system_name} at %{device}") % strings
      RadioButton(Id(dev), name, device == dev)
    end

    def copy_config_widget
      CheckBox(Id(:copy_config), _("Copy whole SSH configuration"), @copy_config)
    end
  end
end

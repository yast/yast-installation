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
  class AutoSshImportDialog < ::Yast::SshImportDialog

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

    def dialog_content
      HSquash(
        VBox(
          Left(Label(_("System to Import SSH Host Keys from"))),
          partitions_list_widget,
          VSpacing(1),
          Left(copy_config_widget)
        )
      )
    end

    def dialog_title
      _("Import SSH Host Keys and Configuration")
    end

  end
end

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

module Installation
  # This class is responsible for building a summary for SshImporter
  # objects. Moving the presentation to a different class, avoid
  # SshImporter knowing about i18n and HTML.
  class SshImporterPresenter
    include Yast::I18n

    # @return [SshImporter] Importer
    attr_reader :importer

    def initialize(importer)
      Yast.import "Mode"
      Yast.import "HTML"

      textdomain "installation"
      @importer = importer
    end

    # Build a formatted summary based on the status of the importer
    #
    # @return [String] HTML formatted summary.
    def summary
      message =
        if importer.configurations.empty? && (Yast::Mode.installation || Yast::Mode.autoinst)
          _("No previous Linux installation found")
        elsif importer.device.nil?
          _("No existing SSH host keys will be copied")
        else
          name = ssh_config.system_name if ssh_config
          name ||= importer.device || "default"
          if importer.copy_config?
            # TRANSLATORS: %s is the name of a Linux system found in the hard
            # disk, like 'openSUSE 13.2'
            _("SSH host keys and configuration will be copied from %s") % name
          else
            # TRANSLATORS: %s is the name of a Linux system found in the hard
            # disk, like 'openSUSE 13.2'
            _("SSH host keys will be copied from %s") % name
          end
        end
      Yast::HTML.List([message])
    end

  private

    # Helper method to access to SshConfig for the selected device
    #
    # @return [::Installation::SshConfig] SSH configuration
    def ssh_config
      # TODO: add a method #current_config to SshImporter (?)
      importer.device ? importer.configurations[importer.device] : nil
    end
  end
end

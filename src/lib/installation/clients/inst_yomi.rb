# Copyright (c) [2021] SUSE LLC
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
require "installation/yomi_runner"
require "installation/salt_client"
require "yaml"
Yast.import "Wizard"
Yast.import "UI"

module Installation
  module Clients
    # This client runs Yomi using a fake pillar. Ideally, it can be adapted
    # in the future to read the pillar data from elsewhere.
    class InstYomi < Yast::Client
      include Yast::Logger

      SALT_API_URL = URI("http://localhost:8000").freeze
      YOMI_PILLAR = "/usr/share/YaST2/lib/installation/yomi.sls".freeze

      def main
        setup_wizard

        runner = Installation::YomiRunner.new
        pillar_data = YAML.load_file(YOMI_PILLAR)
        log.info "Running Salt with #{pillar_data}"
        add_message("Setting up Salt...")
        runner.start_salt(pillar_data)
        add_message("Starting Yomi...")
        runner.start_yomi
        salt_client.events do |event|
          add_message(event.to_s)
        end
      end

    private

      def salt_client
        @salt_client ||= Installation::SaltClient.new(SALT_API_URL).tap do |client|
          client.login("salt", "linux")
        end
      end

      def setup_wizard
        Yast::Wizard.CreateDialog
        Yast::Wizard.SetContents(_("Running Yomi"), RichText(Id(:messages), ""), "", false, false)
      end

      def messages
        @messages ||= []
      end

      def add_message(message)
        messages << message
        update_messages
      end

      def update_messages
        Yast::UI.ChangeWidget(Id(:messages), :Value, messages.join("<br>"))
      end
    end
  end
end

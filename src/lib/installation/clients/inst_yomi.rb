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
require "yaml"

module Installation
  module Clients
    # This client runs Yomi using a fake pillar. Ideally, it can be adapted
    # in the future to read the pillar data from elsewhere.
    class InstYomi < Yast::Client
      include Yast::Logger

      YOMI_PILLAR = "/usr/share/YaST2/lib/installation/yomi.sls".freeze

      def main
        runner = Installation::YomiRunner.new
        pillar_data = YAML.load_file(YOMI_PILLAR)
        log.info "Running Salt with #{pillar_data}"
        runner.run_master_mode(pillar_data)
      end
    end
  end
end

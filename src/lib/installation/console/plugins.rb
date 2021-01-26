# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
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

module Installation
  module Console
    # helper module for loading the console plugins
    module Plugins
      extend Yast::Logger

      # load all console plugins from lib/installation/console/plugins
      # subdirectory
      def self.load_plugins
        # use Yast.y2paths to honor the Y2DIR setting
        plugin_paths = Yast.y2paths.map { |p| File.join(p, "lib/installation/console/plugins") }
        plugin_paths.select { |p| File.directory?(p) }

        plugins = plugin_paths.each_with_object([]) do |p, obj|
          # find all *.rb files
          obj.concat(Dir[File.join(p, "*.rb")])
        end

        log.debug "All found plugins: #{plugins.inspect}"

        # remove the duplicates, this ensures the Y2DIR precedence
        plugins.uniq! do |f|
          File.basename(f)
        end

        plugins.each do |p|
          log.info "Loading plugin #{p}"
          require p
        end
      end
    end
  end
end

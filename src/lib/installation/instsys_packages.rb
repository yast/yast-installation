# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "y2packager/package"

module Installation
  # Find the packages installed in the inst-sys. Because the inst-sys
  # does not contain the RPM DB we need to load the installed packages
  # from the /.packages.root file.
  class InstsysPackages
    def self.read(file = "/.packages.root")
      packages = []

      File.foreach(file) do |line|
        # each line looks like this (the dependency at the end is optional):
        #   yast2-core [4.1.0-5.18.x86_64] < yast2
        name, version = /^(\S+) \[(\S+)\]/.match(line)[1, 2]
        next unless name && version

        # nil repository ID
        packages << Y2Packager::Package.new(name, nil, version)
      end

      packages
    end
  end
end

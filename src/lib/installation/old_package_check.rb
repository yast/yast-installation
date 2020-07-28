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

require "installation/old_package_report"
require "installation/old_package"

module Installation
  # This class checks whether some old packages are selected
  # and displays a warning to the user.
  class OldPackageCheck
    # Read the old package configurations and display warning for the old selected
    # packages.
    def self.run
      old_packages = OldPackage.read
      reporter = OldPackageReport.new(old_packages)
      reporter.report
    end
  end
end

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

Yast.import "Report"
Yast.import "HTML"

module Installation
  # This class checks whether some old packages are selected
  # and displays a warning to the user.
  class OldPackageReport
    include Yast::Logger
    include Yast::I18n

    attr_reader :old_packages

    # @param old_packages [Array<Installation::OldPackage>] old package configurations
    def initialize(old_packages)
      textdomain "installation"
      @old_packages = old_packages
    end

    # report the selected old packages to the user
    def report
      report_packages = old_packages.select(&:selected_old)
      if report_packages.empty?
        log.info "No old package selected"
        return
      end

      log.warn("Detected old packages in the package selection: #{report_packages.inspect}")

      grouped_packages = report_packages.group_by(&:message)

      pkg_summary = grouped_packages.each_with_object("") do |(msg, pkgs), str|
        package_names = pkgs.map do |pkg|
          old = pkg.selected_old
          "#{old["name"]}-#{old["version"]}-#{old["arch"]}"
        end

        str << "<p>"
        str << Yast::HTML.List(package_names)
        str << msg
        str << "</p><br>"
      end

      message = format(_("The installer detected old package versions selected " \
        "for installation: \n\n%{list}"), list: pkg_summary)

      Yast::Report.LongWarning(message)
    end
  end
end

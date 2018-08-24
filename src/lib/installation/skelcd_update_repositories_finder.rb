# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "installation/update_repositories_finder"

module Installation
  class SkelcdUpdateRepositoriesFinder < UpdateRepositoriesFinder

    def updates
      return @updates if @updates

      @updates = Array(custom_update) # Custom URL
      return @updates unless @updates.empty?

      @updates = Array(update_from_control)
    end

  private

    # Return the skelcd update URL according to Linuxrc
    #
    # @return [URI,nil] skelcd update URL. nil if no URL was set in Linuxrc.
    def update_url_from_linuxrc
      cmdline = Yast::Linuxrc.InstallInf("Cmdline").to_s.split(" ")
      entry = cmdline.find {|e| polish(e).start_with?("skelcdupdate=") }
      return unless entry
      get_url_from(entry.split("=")[1].to_s)
    end

    # Return the skelcd update URL according to product's control file
    #
    # @return [URI,nil] skelcd update URL. nil if no URL was set in control file.
    def update_url_from_control
      get_url_from(Yast::ProductFeatures.GetStringFeature("globals", "skelcd_update_url"))
    end

    def polish(entry)
      entry.downcase.tr("-_\.","")
    end
  end
end

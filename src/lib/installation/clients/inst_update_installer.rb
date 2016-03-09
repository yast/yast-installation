require "installation/updates_manager"
require "uri"

module Yast
  class InstUpdateInstaller < Client
    include Yast::Logger

    UPDATED_FILENAME = "installer_updated"

    # TODO
    #
    # * Show progress
    # * Check if network is enabled
    # * Handle unsigned files
    # * Get URL from control file or Linuxrc
    def main
      Yast.import "Directory"

      return :next if installer_updated?

      if update_installer
        ::FileUtils.touch(update_file) # Indicates that the installer was updated.
        :restart_yast # restart YaST to apply modifications.
      else
        :next
      end
    end

    # Tries to update the installer
    #
    # @return [Boolean] true if installer was updated; false otherwise.
    def update_installer
      manager = ::Installation::UpdatesManager.new
      if manager.add_update(URI("http://192.168.122.1:3000/fake.dud"))
        manager.apply_all
      else
        false
      end
    end

    # Check if installer was updated
    #
    # It checks if a file UPDATED_FILENAME exists in Directory.vardir
    #
    # @return [Boolean] true if it exists; false otherwise.
    def installer_updated?
      File.exist?(update_file)
    end

    # Returns the name of the "update file"
    #
    # @return [String] Path to the "update file"
    #
    # @see #update_installer
    def update_file
      File.join(Directory.vardir, UPDATED_FILENAME)
    end
  end
end

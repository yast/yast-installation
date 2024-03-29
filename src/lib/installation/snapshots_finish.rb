require "yast"
require "yast2/fs_snapshot"
require "yast2/fs_snapshot_store"
require "installation/finish_client"
require "y2storage"

module Installation
  class SnapshotsFinish < ::Installation::FinishClient
    include Yast::I18n

    def initialize
      super
      textdomain "installation"

      Yast.import "Mode"
      Yast.import "InstFunctions"
      Yast.import "Report"
      Yast.include self, "installation/misc.rb"
    end

    # Writes configuration
    #
    # It finishes the Snapper configuration, if needed.
    #
    # It also creates a snapshot when no second stage is required and
    # Snapper is configured.
    #
    # @return [TrueClass,FalseClass] True if snapshot was created;
    #                                otherwise it returns false.
    def write
      snapper_config

      skip_reason = nil
      skip_reason = "no second stage" if InstFunctions.second_stage_required?
      skip_reason = "snapper is not configured" unless Yast2::FsSnapshot.configured?
      skip_reason = "root file system is read-only" if ro_root_fs?

      if skip_reason
        log.info("Skipping root filesystem snapshot creation: #{skip_reason}")
        return false
      end

      log.info("Creating root filesystem snapshot")
      if Mode.update
        create_post_snapshot
      else
        create_single_snapshot
      end
    end

    def title
      _("Creating root filesystem snapshot...")
    end

  private

    def create_post_snapshot
      pre_number = Yast2::FsSnapshotStore.load("update")
      # as of bsc #1092757 snapshot descriptions are not translated
      Yast2::FsSnapshot.create_post("after update", pre_number, cleanup: :number, important: true)
      Yast2::FsSnapshotStore.clean("update")
      true
    rescue Yast2::SnapshotCreationFailed, Yast2::FsSnapshotStore::IOError => e
      log.error("Error creating a post-update snapshot: #{e}")
      Yast::Report.Error(_("Could not create a post-update snapshot."))
      false
    end

    def create_single_snapshot
      # as of bsc #1092757 snapshot descriptions are not translated
      Yast2::FsSnapshot.create_single("after installation", cleanup: :number, important: true)
      true
    rescue Yast2::SnapshotCreationFailed => e
      log.error("Error creating a post-installation snapshot: #{e}")
      Yast::Report.Error(_("Could not create a post-installation snapshot."))
      false
    end

    def snapper_config
      if Mode.installation && Yast2::FsSnapshot.configure_on_install?
        log.info("Finishing Snapper configuration")
        Yast2::FsSnapshot.configure_snapper
      else
        log.info("There is no need to configure Snapper")
      end
    end

    # Determines whether the root filesystem is mounted as read-only
    #
    # @return [Boolean] true if it is mounted as read-only; false if it is not
    #   mounted as read-only or if it is not found
    def ro_root_fs?
      staging = Y2Storage::StorageManager.instance.staging
      root_fs = Y2Storage::MountPoint.find_by_path(staging, "/").first
      return false unless root_fs

      root_fs.mount_options.include?("ro")
    end
  end
end

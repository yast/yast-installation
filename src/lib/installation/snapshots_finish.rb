require "yast"
require "yast2/fs_snapshot"
require "yast2/fs_snapshot_store"
require "installation/finish_client"

module Installation
  class SnapshotsFinish < ::Installation::FinishClient
    include Yast::I18n

    def initialize
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

      if !InstFunctions.second_stage_required? && Yast2::FsSnapshot.configured?
        log.info("Creating root filesystem snapshot")
        if Mode.update
          create_post_snapshot
        else
          create_single_snapshot
        end
      else
        log.info("Skipping root filesystem snapshot creation")
        false
      end
    end

    def title
      _("Creating root filesystem snapshot...")
    end

  private

    def create_post_snapshot
      pre_number = Yast2::FsSnapshotStore.load("update")
      # TRANSLATORS: label for filesystem snapshot taken after system update
      Yast2::FsSnapshot.create_post(_("after update"), pre_number, cleanup: :number, important: true)
      Yast2::FsSnapshotStore.clean("update")
      true
    rescue Yast2::SnapshotCreationFailed, Yast2::FsSnapshotsStore::IOError
      Yast::Report.Error(_("Could not create a post-update snapshot."))
      false
    end

    def create_single_snapshot
      # TRANSLATORS: label for filesystem snapshot taken after system installation
      Yast2::FsSnapshot.create_single(_("after installation"), cleanup: :number, important: true)
      true
    rescue Yast2::SnapshotCreationFailed
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
  end
end

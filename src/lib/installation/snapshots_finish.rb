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
      Yast.include self, "installation/misc.rb"
    end

    # Writes configuration
    #
    # It creates a snapshot when no second stage is required and
    # Snapper is configured.
    #
    # @return [TrueClass,FalseClass] True if snapshot was created;
    #                                otherwise it returns false.
    def write
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
      Yast2::FsSnapshot.create_post("after update", pre_number, cleanup: :number, important: true)
      Yast2::FsSnapshotStore.clean("update")
      true
    end

    def create_single_snapshot
      Yast2::FsSnapshot.create_single("after installation", cleanup: :number, important: true)
      true
    end
  end
end

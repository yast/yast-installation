#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/umount_finish"

describe Yast::UmountFinishClient do
  subject(:client) { described_class.new }

  DEFAULT_SUBVOLUME = "@/.snapshots/1/snapshot".freeze

  describe "#set_btrfs_defaults_as_ro" do
    before do
      allow(Y2Storage::VolumeSpecification).to receive(:for)
        .and_return(root_spec)
      allow(Yast::Execute).to receive(:on_target)
        .with("btrfs", "subvolume", "get-default", "/", anything)
        .and_return("ID 276 gen 1172 top level 275 path @/.snapshots/1/snapshot\n")
      allow(Y2Storage::StorageManager.instance).to receive(:staging).and_return(devicegraph)
    end

    let(:devicegraph) do
      instance_double(Y2Storage::Devicegraph, filesystems: [root_fs])
    end

    let(:root_fs) do
      instance_double(
        Y2Storage::Filesystems::Btrfs,
        is?:           true,
        mount_point:   mount_point,
        mount_options: mount_options
      )
    end

    let(:mount_point) { instance_double(Y2Storage::MountPoint, path: "/") }
    let(:mount_options) { ["ro"] }

    let(:root_spec) do
      instance_double(Y2Storage::VolumeSpecification, btrfs_default_subvolume: "@")
    end

    context "when a Btrfs filesystem is mounted as read-only" do
      it "sets 'ro' property to true on the default subvolume" do
        expect(Yast::Execute).to receive(:on_target)
          .with("btrfs", "property", "set", ".snapshots/1/snapshot", "ro", "true")
        client.set_btrfs_defaults_as_ro
      end
    end

    context "when a non-Btrfs filesystem is mounted" do
      let(:root_fs) { instance_double(Y2Storage::Filesystems::Base, is?: false) }

      it "does not try to set 'ro' property for that filesystem" do
        expect(Yast::Execute).to_not receive(:on_target)
          .with("btrfs", "property", "set", any_args)
        client.set_btrfs_defaults_as_ro
      end
    end

    context "when no Btrfs fileystem is mounted as read-only" do
      let(:mount_options) { [] }

      it "does not try to set 'ro' property" do
        expect(Yast::Execute).to_not receive(:on_target)
          .with("btrfs", "property", "set", any_args)
        client.set_btrfs_defaults_as_ro
      end
    end
  end
end

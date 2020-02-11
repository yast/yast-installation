#! /usr/bin/env rspec

require_relative "../test_helper"
require_yupdate

describe YUpdate::InstSys do
  describe ".check!" do
    context "when running in an inst-sys" do
      before do
        expect(described_class).to receive(:`).with("mount").and_return(<<-MOUNT
tmpfs on / type tmpfs (rw,relatime,size=1508624k,nr_inodes=0)
tmpfs on / type tmpfs (rw,relatime,size=1508624k,nr_inodes=0)
proc on /proc type proc (rw,relatime)
sysfs on /sys type sysfs (rw,relatime)
MOUNT
        )
      end

      it "does not exit" do
        expect(described_class).to_not receive(:exit)
        described_class.check!
      end
    end

    context "when running in a normal system" do
      before do
        expect(described_class).to receive(:`).with("mount").and_return(<<-MOUNT
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
/dev/sda1 on / type btrfs (rw,relatime,ssd,space_cache,subvolid=267,subvol=/@/.snapshots/1/snapshot)
/dev/sda2 on /home type ext4 (rw,relatime,stripe=32596,data=ordered)
MOUNT
        )
        allow(described_class).to receive(:exit).with(1)
      end

      it "exits with status 1" do
        expect(described_class).to receive(:exit).with(1)
        # capture the std streams just to not break the rspec output
        capture_stdio { described_class.check! }
      end

      it "prints an error on STDERR" do
        _stdout, stderr = capture_stdio { described_class.check! }
        expect(stderr).to match(/ERROR: .*inst-sys/)
      end
    end
  end
end

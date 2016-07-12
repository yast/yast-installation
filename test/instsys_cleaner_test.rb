#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/instsys_cleaner"

def stub_logging
end

describe Installation::InstsysCleaner do
  describe ".make_clean" do
    context "in the initial stage" do
      before do
        expect(Yast::Stage).to receive(:initial).and_return(true)
        expect(Yast::Mode).to receive(:installation).and_return(true)

        # mock the logged memory stats
        allow(subject.class).to receive(:`).with("df -m").and_return("")
        allow(subject.class).to receive(:`).with("free -m").and_return("")
      end

      it "removes the libzypp cache if the memory less than 640MB" do
        # 512MB - 1B
        expect(Yast2::HwDetection).to receive(:memory).and_return((512 << 20) - 1)
        allow(subject.class).to receive(:unmount_kernel_modules)

        expect(FileUtils).to receive(:rm_rf).with(Installation::InstsysCleaner::LIBZYPP_CACHE_PATH)

        subject.class.make_clean
      end

      it "removes the kernel modules if the memory less than 1GB" do
        # 1GB - 1B
        expect(Yast2::HwDetection).to receive(:memory).and_return((1 << 30) - 1)
        allow(subject.class).to receive(:cleanup_zypp_cache)

        # the order of the executed commands is important, check it explicitly
        expect(File).to receive(:exist?).with("/parts/mp_0000/lib/modules").and_return(true).ordered
        expect(subject.class).to receive(:`).with("mount").and_return(load_fixture("inst-sys", "mount.out")).ordered
        expect(subject.class).to receive(:`).with("losetup -n -O BACK-FILE /dev/loop0")
          .and_return(load_fixture("inst-sys", "losetup.out")).ordered
        expect(subject.class).to receive(:`).with("umount /parts/mp_0000").ordered
        expect(subject.class).to receive(:`).with("losetup -d /dev/loop0").ordered
        expect(FileUtils).to receive(:rm_rf).with("/parts/00_lib").ordered

        subject.class.make_clean
      end

      it "does not remove anything if there is enough memory" do
        # 2GB RAM
        expect(Yast2::HwDetection).to receive(:memory).and_return(2 << 30)

        expect(subject.class).to_not receive(:cleanup_zypp_cache)
        expect(subject.class).to_not receive(:unmount_kernel_modules)

        subject.class.make_clean
      end
    end

    context "outside the initial stage" do
      before do
        expect(Yast::Stage).to receive(:initial).and_return(false)
      end

      it "does not do anything" do
        expect(subject.class).to_not receive(:cleanup_zypp_cache)
        expect(subject.class).to_not receive(:unmount_kernel_modules)

        subject.class.make_clean
      end
    end
  end
end

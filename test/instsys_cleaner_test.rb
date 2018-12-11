#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/instsys_cleaner"

describe Installation::InstsysCleaner do
  describe ".make_clean" do
    context "in the initial stage" do
      before do
        expect(Yast::Stage).to receive(:initial).and_return(true)
        expect(Yast::Mode).to receive(:installation).and_return(true)

        # mock the logged memory stats
        allow(Yast::Execute).to receive(:locally).with("df", "-m")
        allow(Yast::Execute).to receive(:locally).with("free", "-m")
        allow(File).to receive(:size).and_return(0)
        allow(Dir).to receive(:[]).and_return([])
        allow(Yast::UI).to receive(:TextMode).and_return(true)
      end

      context "a bit less than 640MB memory in text mode" do
        before do
          # 512MB - 1B
          expect(Yast2::HwDetection).to receive(:memory).and_return((512 << 20) - 1)
          allow(described_class).to receive(:unmount_kernel_modules)
        end

        fit "does not remove anything if no known file is found" do
          expect(FileUtils).to_not receive(:rm)
          described_class.make_clean
        end

        it "removes the known files from the libzypp cache" do
          file = "/var/cache/zypp/raw/SLES15-15-0/repodata/1234567890abcdef-appdata.xml.gz"
          expect(Dir).to receive(:[]).with("/var/cache/zypp/raw/**/*-appdata.xml.gz")
            .and_return([file])
          expect(FileUtils).to receive(:rm).with(file)
          described_class.make_clean
        end
      end

      context "a bit less than 1GB memory in graphical mode" do
        before do
          # 1GB - 1B
          expect(Yast2::HwDetection).to receive(:memory).and_return((1 << 30) - 1)
          allow(described_class).to receive(:unmount_kernel_modules)
          allow(Yast::UI).to receive(:TextMode).and_return(false)
        end

        it "removes the known files from the libzypp cache" do
          file = "/var/cache/zypp/raw/SLES15-15-0/repodata/1234567890abcdef-appdata.xml.gz"
          expect(Dir).to receive(:[]).with("/var/cache/zypp/raw/**/*-appdata.xml.gz")
            .and_return([file])
          expect(FileUtils).to receive(:rm).with(file)
          described_class.make_clean
        end
      end

      context "a bit less than 1GB memory in text mode" do
        before do
          # 1GB - 1B
          expect(Yast2::HwDetection).to receive(:memory).and_return((1 << 30) - 1)
          allow(described_class).to receive(:unmount_kernel_modules)
        end

        fit "does not remove the libzypp cache" do
          expect(described_class).to_not receive(:cleanup_zypp_cache)
          described_class.make_clean
        end
      end

      it "removes the kernel modules if the memory is less than 1GB" do
        # 1GB - 1B
        expect(Yast2::HwDetection).to receive(:memory).and_return((1 << 30) - 1)
        allow(described_class).to receive(:cleanup_zypp_cache)

        # the order of the executed commands is important, check it explicitly
        expect(File).to receive(:exist?).with("/parts/mp_0000/lib/modules").and_return(true).ordered
        expect(Yast::Execute).to receive(:locally).with("mount", stdout: :capture).and_return(load_fixture("inst-sys", "mount.out")).ordered
        expect(Yast::Execute).to receive(:locally).with("losetup", "-n", "-O", "BACK-FILE", "/dev/loop0", stdout: :capture)
          .and_return(load_fixture("inst-sys", "losetup.out")).ordered
        expect(Yast::Execute).to receive(:locally).with("umount", "/parts/mp_0000").ordered
        expect(Yast::Execute).to receive(:locally).with("losetup", "-d", "/dev/loop0").ordered
        expect(FileUtils).to receive(:rm_rf).with("/parts/00_lib").ordered

        described_class.make_clean
      end

      it "does not remove anything if there is enough memory" do
        # 2GB RAM
        expect(Yast2::HwDetection).to receive(:memory).and_return(2 << 30)

        expect(described_class).to_not receive(:cleanup_zypp_cache)
        expect(described_class).to_not receive(:unmount_kernel_modules)

        described_class.make_clean
      end
    end

    context "outside the initial stage" do
      before do
        expect(Yast::Stage).to receive(:initial).and_return(false)
      end

      it "does not do anything" do
        expect(described_class).to_not receive(:cleanup_zypp_cache)
        expect(described_class).to_not receive(:unmount_kernel_modules)

        described_class.make_clean
      end
    end
  end
end

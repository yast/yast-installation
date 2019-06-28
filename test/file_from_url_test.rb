#!/usr/bin/env rspec

require_relative "test_helper"

require "transfer/file_from_url"

describe Yast::Transfer::FileFromUrl do
  Yast.import "Installation"

  before do
    stub_const("Yast::FTP", double(fake_method: nil))
    stub_const("Yast::HTTP", double(Get: nil))
    stub_const("Yast::TFTP", double(Get: nil))
  end

  class FileFromUrlTest
    include Yast::I18n
    include Yast::Transfer::FileFromUrl

    # adaptor for existing tests
    def Get(scheme, host, urlpath, localfile)
      get_file_from_url(scheme: scheme, host: host, urlpath: urlpath,
                        localfile: localfile,
                        urltok: {}, destdir: "/destdir")
    end
  end

  # avoid BuildRequiring a package that we stub entirely anyway
  before do
    allow(Yast).to receive(:import).and_call_original
  end

  subject { FileFromUrlTest.new }

  describe "#Get" do
    before do
      expect(Yast::WFM).to receive(:Read)
        .and_return("/tmp_dir")
      expect(Yast::WFM).to receive(:SCRGetDefault)
        .and_return(333)
      expect(Yast::WFM).to receive(:SCRGetName).with(333)
        .and_return("chroot=/mnt:scr")
      expect(Yast::WFM).to receive(:Execute)
        .with(path(".local.mkdir"), "/destdir/tmp_dir/tmp_mount")
      # the local/target mess was last modified in
      # https://github.com/yast/yast-autoinstallation/commit/69f1966dd1456301a69102c6d3bacfe7c9f9dc49
      # for https://bugzilla.suse.com/show_bug.cgi?id=829265

      allow(Yast::Execute).to receive(:new).and_return(execute_object)
    end

    let(:execute_object) { Yast::Execute.new }

    it "returns false for unknown scheme" do
      expect(subject.Get("money_transfer_protocol",
        "bank", "account", "pocket")).to eq(false)
    end

    context "when scheme is 'device'" do
      let(:scheme) { "device" }

      it "returns false for an empty path" do
        expect(subject.Get(scheme, "sda", "", "/localfile")).to eq(false)
      end

      context "when host is empty" do
        let(:host) { "" }

        it "probes disks" do
          probed_disks = [
            {},
            { "dev_name" => "/dev/sda" },
            { "dev_name" => "/dev/sdb" }
          ]

          expect(Yast::SCR).to receive(:Read)
            .with(path(".probe.disk"))
            .and_return(probed_disks)

          lstat_mocks = {
            "/dev/sda1" => true,
            "/dev/sda2" => false,
            "/dev/sda3" => false,
            "/dev/sda4" => true,
            "/dev/sda5" => true,
            "/dev/sda6" => false,

            "/dev/sdb1" => true,
            "/dev/sdb2" => false,
            "/dev/sdb3" => false,
            "/dev/sdb4" => false,
            "/dev/sdb5" => false
          }

          lstat_mocks.each do |device, exists|
            expect(Yast::SCR).to receive(:Read)
              .with(path(".target.lstat"), device).twice
              .and_return(exists ? { "size" => 1 } : {})
          end

          allow(Yast::SCR).to receive(:Dir)
            .with(path(".product.features.section")).and_return([])

          # only up to sda5 because that is when we find the file
          mount_points = {
            # device    => [prior mount point, temporary mount point]
            "/dev/sda"  => ["",          "/tmp_dir/tmp_mount"],
            "/dev/sda1" => ["/mnt_sda1", nil],
            "/dev/sda4" => ["",          "/mnt_sda1"],
            "/dev/sda5" => ["",          "/mnt_sda1"]
          }

          mount_points.each do |device, mp|
            expect(execute_object).to receive(:stdout)
              .with("/usr/bin/findmnt", "--first-only", "--noheadings", "--output=target", device)
              .and_return(mp.first)
          end

          # only up to sda5 because that is when we find the file
          mount_succeeded = {
            "/dev/sda"  => false,
            "/dev/sda4" => true,
            "/dev/sda5" => true
          }

          mount_succeeded.each do |device, result|
            expect(Yast::SCR).to receive(:Execute)
              .with(path(".target.mount"),
                [device, mount_points[device].last],
                "-o noatime")
              .and_return(result)
          end

          expect(Yast::WFM).to receive(:Execute)
            .with(path(".local.bash"),
              "/bin/cp /mnt_sda1/mypath /localfile")
            .exactly(3).times
            .and_return(1, 1, 0) # sda1 fails, sda4 fails, sda5 succeeds

          expect(Yast::WFM).to receive(:Execute)
            .with(path(".local.bash"),
              #                  "/bin/cp /destdir/tmp_dir/tmp_mount/mypath /localfile")
              # Bug: it is wrong if destdir is used
              "/bin/cp /tmp_dir/tmp_mount/mypath /localfile")
            .exactly(0).times
          #            .and_return(1, 0)   # sda4 fails, sda5 succeeds

          # Bug: local is wrong. nfs and cifs correctly use .target.umount
          expect(Yast::WFM).to receive(:Execute)
            .with(path(".local.umount"), "/mnt_sda1")
            .exactly(2).times

          # DO IT, this is the call that needs all the above mocking
          expect(subject.Get(scheme, host, "mypath", "/localfile"))
            .to eq(true)
        end

      end

      context "when host specifies a device" do
      end

      context "when host+path specify a device" do
      end
    end

    context "when scheme is 'usb'" do
      let(:scheme) { "usb" }

      it "returns false for an empty path" do
        expect(subject.Get(scheme, "sda", "", "/localfile")).to eq(false)
      end
    end

    # not yet covered
    context "when scheme is 'http' or 'https'" do
    end
    context "when scheme is 'ftp'" do
    end
    context "when scheme is 'file'" do
      let(:scheme) { "file" }
      let(:destination) { "/tmp/auto.xml" }
      let(:source) { "/oss.xml" }
      let(:cd_device) { "/dev/sr0" }
      let(:tmp_mount) { "/tmp_dir/tmp_mount" }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), "/bin/cp #{tmp_mount}/#{source} #{destination}")
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), "/bin/cp #{source} #{destination}")
        allow(Yast::WFM).to receive(:Execute)
          .with(Yast::Path.new(".local.umount"), tmp_mount)
        allow(Yast::Installation).to receive(:sourcedir).and_return("/mnt")
        allow(Yast::Installation).to receive(:boot).and_return("cd")
        allow(Yast::InstURL).to receive("installInf2Url").and_return("cd:/?devices=#{cd_device}")
        expect(Yast::SCR).to receive(:Read)
          .with(Yast::Path.new(".target.size"), "/mnt/#{source}").and_return(0)
        expect(Yast::SCR).to receive(:Read)
          .with(Yast::Path.new(".target.size"), destination).and_return(0, 10)
      end

      context "CD has already been mounted multiple times" do
        before do
          allow(File).to receive(:read).with("/proc/mounts").and_return(
            "#{cd_device} /mounts/mp_0005 iso9660 ro,relatime 0 0\n"\
            "#{cd_device} /mounts/mp_0006 iso9660 ro,relatime 0 0"
          )
        end

        it "mounts with --bind option and returns true" do
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash_output"),
              "/bin/mount -v --bind /mounts/mp_0005 #{tmp_mount}")
            .and_return("exit" => 0, "stdout" => "ok")
          expect(subject.Get(scheme, "", source, destination)).to eq(true)
        end
      end

      context "CD has not been mounted" do
        before do
          allow(File).to receive(:read).with("/proc/mounts").and_return("")
        end

        it "mounts CD and returns true" do
          expect(Yast::WFM).to receive(:Execute)
            .with(Yast::Path.new(".local.mount"),
              [cd_device, tmp_mount, Yast::Installation.mountlog])
            .and_return(true)
          expect(subject.Get(scheme, "", source, destination)).to eq(true)
        end
      end
    end
    context "when scheme is 'nfs'" do
    end
    context "when scheme is 'cifs'" do
    end
    context "when scheme is 'floppy'" do
    end
    context "when scheme is 'tftp'" do
    end
  end
end

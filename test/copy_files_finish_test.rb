require_relative "./test_helper.rb"

require "installation/clients/copy_files_finish"

describe Yast::CopyFilesFinishClient do
  describe "#modes" do
    it "defines that it runs in installation" do
      expect(subject.modes).to include(:installation)
    end

    it "defines that it runs in update" do
      expect(subject.modes).to include(:update)
    end

    it "defines that it runs in autoinstallation" do
      expect(subject.modes).to include(:autoinst)
    end
  end

  describe "#title" do
    it "returns string with localized title" do
      expect(subject.title).to be_a(::String)
    end
  end

  describe "#write" do
    before do
      # ensure that nothing will be written to system
      stub_const("::FileUtils", double.as_null_object)
      stub_const("::Yast::SCR", double.as_null_object)
      stub_const("::Yast::WFM", double.as_null_object)
      allow(Yast::Installation).to receive(:destdir).and_return("/mnt")
      allow(::File).to receive(:exist?).and_return(false)
      allow(::File).to receive(:read).and_return("")
      allow(::File).to receive(:write)
      allow(Yast::Linuxrc).to receive(:InstallInf)
      allow(Yast::Packages).to receive(:GetBaseSourceID).and_return(1)
      allow(::Installation::SshImporter).to receive(:instance).and_return(double.as_null_object)
    end

    it "appends modules blacklisted in linuxrc to target system blacklist" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("BrokenModules").and_return("moduleA, moduleB")
      blacklist_file = "/mnt/etc/modprobe.d/50-blacklist.conf"
      allow(::File).to receive(:exist?).with(blacklist_file).and_return(true)
      expect(::File).to receive(:read).with(blacklist_file).and_return("First Line")
      expect(::File).to receive(:write).with(blacklist_file, String) do |_path, content|
        expect(content).to match(/# Note: Entries added during installation\/update/)
        expect(content).to match(/blacklist moduleA/)
        expect(content).to match(/blacklist moduleB/)
      end

      subject.write
    end

    it "copies information about hardware status" do
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib")
      expect(Yast::WFM).to receive(:Execute).with(path(".local.bash"), /cp.*\/var\/lib\/hardware/)

      subject.write
    end

    it "copies VNC setup data when VNC installation is used" do
      allow(Yast::Linuxrc).to receive(:vnc).and_return(true)

      expect(Yast::WFM).to receive(:Execute).with(path(".local.bash"), /cp.*\/root\/.vnc/)

      subject.write
    end

    it "copies multipath stuff in installation only" do
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(::FileUtils).to receive(:cp)
      allow(::FileUtils).to receive(:mkdir_p)
      allow(::File).to receive(:exist?).with("/etc/multipath/wwids").and_return(true)

      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/etc/multipath")
      expect(::FileUtils).to receive(:cp).with("/etc/multipath/wwids", "/mnt/etc/multipath/wwids")

      subject.write
    end

    it "copies cio_ignore whitelist in installation of s390 only" do
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
      allow(::FileUtils).to receive(:cp)
      allow(::FileUtils).to receive(:mkdir_p)
      allow(::File).to receive(:exist?).with("/boot/zipl/active_devices.txt").and_return(true)

      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/boot/zipl")
      expect(::FileUtils).to receive(:cp).with("/boot/zipl/active_devices.txt", "/mnt/boot/zipl/active_devices.txt")

      subject.write
    end

    it "saves install.inf if second stage is required" do
      allow(Yast::InstFunctions).to receive(:second_stage_required?).and_return(true)

      expect(Yast::Linuxrc).to receive(:SaveInstallInf).with("/mnt")

      subject.write
    end

    it "deletes install.inf if second stage is not required" do
      allow(Yast::InstFunctions).to receive(:second_stage_required?).and_return(false)

      expect(::FileUtils).to receive(:rm).with("/etc/install.inf")

      subject.write
    end

    it "copies control.xml" do
      allow(::FileUtils).to receive(:cp)
      allow(Yast::ProductControl).to receive(:current_control_file).and_return("/control.xml")

      expect(::FileUtils).to receive(:cp).with("/control.xml", "/mnt/etc/YaST2/control.xml")

      subject.write
    end

    it "ensures proper permission on copied control.xml" do
      allow(Yast::ProductControl).to receive(:current_control_file).and_return("/control.xml")

      expect(::FileUtils).to receive(:chmod).with(0o644, "/mnt/etc/YaST2/control.xml")

      subject.write
    end

    it "copies build file" do
      allow(Yast::Pkg).to receive(:SourceProvideOptionalFile).with(1, 1, "/media.1/build")
        .and_return("/media.1/build")

      expect(::FileUtils).to receive(:cp).with("/media.1/build", "/mnt/etc/YaST2/build")

      subject.write
    end

    it "ensures proper permission on copied build file" do
      allow(Yast::Pkg).to receive(:SourceProvideOptionalFile).with(1, 1, "/media.1/build")
        .and_return("/media.1/build")

      expect(::FileUtils).to receive(:chmod).with(0o644, "/mnt/etc/YaST2/build")

      subject.write
    end

    it "copies all product profiles" do
      allow(Yast::ProductProfile).to receive(:all_profiles).and_return(["/product1.xml", "/product2.xml"])
      allow(::FileUtils).to receive(:mkdir_p)

      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/etc/productprofiles.d")
      expect(::Yast::WFM).to receive(:Execute).with(path(".local.bash"), /cp.*\/product1.xml/)
      expect(::Yast::WFM).to receive(:Execute).with(path(".local.bash"), /cp.*\/product2.xml/)

      subject.write
    end

    it "copies all used control files" do
      allow(Yast::WorkflowManager).to receive(:GetAllUsedControlFiles).and_return(["/control.xml", "/addon/addon.xml"])

      expect(::FileUtils).to receive(:rm_rf).with("/mnt/etc/YaST2/control_files")
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/etc/YaST2/control_files")

      expect(::FileUtils).to receive(:cp).with("/control.xml", "/mnt/etc/YaST2/control_files")
      expect(::FileUtils).to receive(:cp).with("/addon/addon.xml", "/mnt/etc/YaST2/control_files")

      subject.write
    end

    it "ensures proper permissions of copied used control files" do
      allow(Yast::WorkflowManager).to receive(:GetAllUsedControlFiles).and_return(["/control.xml", "/addon/addon.xml"])

      expect(::FileUtils).to receive(:chmod).with(0o644, "/mnt/etc/YaST2/control_files/control.xml")
      expect(::FileUtils).to receive(:chmod).with(0o644, "/mnt/etc/YaST2/control_files/addon.xml")

      subject.write
    end

    it "writes order of control files to order.ycp" do
      allow(Yast::WorkflowManager).to receive(:GetAllUsedControlFiles).and_return(["/control.xml", "/addon/addon.xml"])

      expect(Yast::SCR).to receive(:Write).with(
        path(".target.ycp"),
        "/mnt/etc/YaST2/control_files/order.ycp",
        ["control.xml", "addon.xml"]
      )

      subject.write
    end

    it "ensures proper permission for order.ycp" do
      allow(Yast::WorkflowManager).to receive(:GetAllUsedControlFiles).and_return(["/control.xml", "/addon/addon.xml"])

      expect(::FileUtils).to receive(:chmod).with(0o644, "/mnt/etc/YaST2/control_files/order.ycp")

      subject.write
    end

    it "save insts-sys content specified in control file" do
      expect(Yast::SystemFilesCopy).to receive(:SaveInstSysContent)

      subject.write
    end

    it "copies udev rules in installation" do
      allow(Yast::Mode).to receive(:update).and_return(false)

      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/etc/udev/rules.d")
      expect(::Yast::WFM).to receive(:Execute).with(path(".local.bash_output"), /cp.*\/etc\/udev\/rules.d/)
        .and_return("exit" => 0)

      subject.write
    end

    it "copies ssh files" do
      expect(::Installation::SshImporter.instance).to receive(:write).with("/mnt")

      subject.write
    end
  end
end

require_relative "test_helper"
require "installation/clients/desktop_finish"

describe Yast::DesktopFinishClient do
  describe "#title" do
    it "returns translated string" do
      expect(subject.title).to be_a(::String)
    end
  end

  describe "#modes" do
    it "runs in installation" do
      expect(subject.modes).to include(:installation)
    end

    it "runs in autoinstallation" do
      expect(subject.modes).to include(:autoinst)
    end

    it "does not run in update" do
      expect(subject.modes).to_not include(:update)
    end
  end

  describe "#write" do
    before do
      allow(Yast::DefaultDesktop).to receive(:Desktop).and_return("gnome")
      allow(Yast::DefaultDesktop).to receive(:GetAllDesktopsMap)
        .and_return("gnome" => {
                      "logon"   => "gdm",
                      "cursor"  => "DMZ",
                      "desktop" => "gnome"
                    })

      allow(Yast::SCR).to receive(:Write)
      allow(Yast::Execute).to receive(:on_target)
    end

    it "do nothing if no desktop is selected" do
      allow(Yast::DefaultDesktop).to receive(:Desktop).and_return(nil)
      expect(Yast::SCR).to_not receive(:Write)
      expect(Yast::Execute).to_not receive(:on_target)

      subject.write
    end

    it "writes default wm for selected desktop" do
      expect(Yast::SCR).to receive(:Write)
        .with(path(".sysconfig.windowmanager.DEFAULT_WM"), "gnome")

      subject.write
    end

    it "writes cursor for selected desktop" do
      expect(Yast::SCR).to receive(:Write)
        .with(path(".sysconfig.windowmanager.X_MOUSE_CURSOR"), "DMZ")

      subject.write
    end

    it "does not write the displaymanager (bsc#1125040)" do
      expect(Yast::SCR).to_not receive(:Write)
        .with(path(".sysconfig.displaymanager.DISPLAYMANAGER"), anything)

      subject.write
    end
  end
end

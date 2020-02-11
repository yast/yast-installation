#! /usr/bin/env rspec

require_relative "../test_helper"
require_yupdate

describe YUpdate::GemInstaller do
  describe "#install_required_gems" do
    before do
      allow(File).to receive(:exist?).with("/usr/bin/rake").and_return(true)
      allow_any_instance_of(YUpdate::OverlayFS).to receive :create
      allow(subject).to receive(:gem).and_raise(Gem::LoadError)
      allow(subject).to receive(:system)
    end

    it "installs the required gems" do
      allow(subject).to receive(:system).with("gem install --no-document --no-format-exec yast-rake")
      subject.install_required_gems
    end

    it "skips already installed gems" do
      expect(subject).to receive(:gem).and_return(true)
      expect(subject).to_not receive(:system)
      subject.install_required_gems
    end

    it "it makes the gem directory writable" do
      ovfs = double
      expect(YUpdate::OverlayFS).to receive(:new).with(Gem.dir).and_return(ovfs)
      expect(ovfs).to receive(:create)

      subject.install_required_gems
    end
  end
end

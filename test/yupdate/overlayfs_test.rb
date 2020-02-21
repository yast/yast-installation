#! /usr/bin/env rspec

require_relative "../test_helper"
require_yupdate

describe YUpdate::OverlayFS do
  # testing data
  let(:orig_path) { "/test/test__test" }
  let(:escaped_path) { "/var/lib/YaST2/overlayfs/upper/_test_test____test" }

  before do
    # mock the checks for existing directory
    allow(File).to receive(:realpath) { |d| d }
    allow(File).to receive(:directory?).and_return(true)
  end

  describe "#upperdir" do
    it "returns the path in the 'upper' subdirectory" do
      o = YUpdate::OverlayFS.new(orig_path)
      expect(o.upperdir).to match(/\/upper\//)
    end
  end

  describe ".escape_path" do
    it "escapes the path and adds a prefix" do
      expect(YUpdate::OverlayFS.escape_path("upper", orig_path)).to eq(escaped_path)
    end
  end

  describe ".unescape_path" do
    it "unescapes the path and removes the prefix" do
      expect(YUpdate::OverlayFS.unescape_path(escaped_path)).to eq(orig_path)
    end
  end
end

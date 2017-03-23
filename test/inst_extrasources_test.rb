#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/clients/inst_extrasources"

describe Yast::InstExtrasourcesClient do
  describe "#RegisteredUrls" do
    before do
      # fake main run, to avoid huge stubbing
      subject.instance_variable_set(:"@local_urls", {})
      subject.instance_variable_set(:"@usb_sources", {})

      allow(Yast::Pkg).to receive(:SourceGetCurrent).with(false).and_return([0, 1, 2, 3])
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(0).and_return("url" => "http://test.com/")
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(1)
        .and_return("url" => "usb://device=/dev/disk/by-id/usb-15")
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(2).and_return("url" => "dir:///mnt/path")
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(3).and_return({})
    end

    it "returns list of urls for registered repositories without trailing slash" do
      expect(subject.RegisteredUrls).to eq [
        "http://test.com", "usb://device=/dev/disk/by-id/usb-15", "dir:///mnt/path"
      ]
    end

    it "fills list of local_urls in update Mode" do
      allow(Yast::Mode).to receive(:update).and_return(true)
      subject.RegisteredUrls

      expect(subject.instance_variable_get(:"@local_urls")).to eq(2 => "dir:///mnt/path")
    end

    it "fills list of usb sources" do
      subject.RegisteredUrls

      expect(subject.instance_variable_get(:"@usb_sources")).to eq(
        1 => "usb://device=/dev/disk/by-id/usb-15"
      )
    end
  end

  describe "#GetURLsToRegister" do
    it "returns extra_urls entries from product " \
       "without already registered entries passed as argument" do
      already_registered = "http://test.com"
      allow(Yast::ProductFeatures).to receive(:GetFeature).with("software", "extra_urls")
        .and_return([{ "baseurl" => "http://test.com/" }, { "baseurl" => "http://test2.com" }])

      expect(subject.GetURLsToRegister(already_registered)).to eq(
        [{ "baseurl" => "http://test2.com" }]
      )
    end
  end
end

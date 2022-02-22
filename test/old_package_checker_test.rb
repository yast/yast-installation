#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/old_package_checker"

describe Installation::OldPackageChecker do
  describe ".run" do
    it "reads old package configurations and reports the old packages" do
      expect(Installation::OldPackage).to receive(:read)
      expect_any_instance_of(Installation::OldPackageReporter).to receive(:report)
      Installation::OldPackageChecker.run
    end
  end
end

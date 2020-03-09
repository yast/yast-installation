#!/usr/bin/env rspec
# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "test_helper"

require "uri"
require "installation/selfupdate_verifier"
require "installation/update_repository"
require "installation/instsys_packages"
require "y2packager/resolvable"

def create_package_resolvable(name, version)
  Y2Packager::Resolvable.new("kind" => :package, "name" => name, "source" => nil,
    "version" => version, "arch" => "x86_64", "deps" => [])
end

describe Installation::SelfupdateVerifier do
  let(:test_file) { File.join(FIXTURES_DIR, "inst-sys", "packages.root") }
  let(:repo) do
    Installation::UpdateRepository.new(URI("http://example.com"))
  end

  # this one is downgraded
  let(:downgraded_pkg) { create_package_resolvable("yast2", "4.1.7-1.2") }
  # downgraded non-YaST package
  let(:downgraded_nony2_pkg) { create_package_resolvable("rpm", "3.1.2-1.2") }
  # this one is upgraded a bit
  let(:upgraded_pkg) { create_package_resolvable("yast2-installation", "4.2.37-1.1") }
  # this one is upgraded too much
  let(:too_new) { create_package_resolvable("yast2-packager", "4.3.11-1.3") }

  let(:instsys_packages) { Installation::InstsysPackages.read(test_file) }

  subject { Installation::SelfupdateVerifier.new([repo], instsys_packages) }

  before do
    expect(repo).to receive(:packages).and_return(
      [downgraded_pkg, upgraded_pkg, too_new, downgraded_nony2_pkg]
    )
  end

  describe "#downgraded_packages" do
    it "returns the downgraded packages" do
      expect(subject.downgraded_packages).to eq([downgraded_pkg])
    end
  end

  describe "#too_new_packages" do
    it "returns the too new packages" do
      expect(subject.too_new_packages).to eq([too_new])
    end
  end

end

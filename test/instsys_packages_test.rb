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

require "installation/instsys_packages"

describe Installation::InstsysPackages do

  let(:test_file) { File.join(FIXTURES_DIR, "inst-sys", "packages.root") }

  describe ".read" do
    it "reads the packages from a file" do
      pkgs = Installation::InstsysPackages.read(test_file)

      expect(pkgs).to_not be_empty
      expect(pkgs.first).to be_a(Y2Packager::Package)
    end

    it "reads the package versions" do
      pkgs = Installation::InstsysPackages.read(test_file)
      yast2 = pkgs.find { |p| p.name == "yast2" }

      expect(yast2.version).to eq("4.2.67-1.7.x86_64")
    end
  end
end

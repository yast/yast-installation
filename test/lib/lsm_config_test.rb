#!/usr/bin/env rspec

# Copyright (c) [2017-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper.rb"
require "installation/lsm_config"

describe Installation::LSMConfig do
  let(:configurable) { true }
  let(:section) { { "default" => "selinux", "configurable" => configurable } }

  before do
    allow(Yast::ProductFeatures).to receive("GetFeature").with("globals", "lsm").and_return(section)
  end

  describe "#propose_default" do
    it "selects the LSM to be used based on the control file" do
      expect { subject.propose_default }.to change { subject.selected&.id }.from(nil).to(:selinux)
    end

    context "when no default LSM is declared in the control file" do
      let(:section) { { "configurable" => configurable } }

      it "fallbacks to :apparmor" do
        expect { subject.propose_default }
          .to change { subject.selected&.id }.from(nil).to(:apparmor)
      end
    end
  end

  describe "#configurable?" do
    context "when LSM is declared in the profile as not configurable" do
      let(:configurable) { false }

      it "returns false" do
        expect(subject.configurable?).to eql(false)
      end
    end

    it "returns true" do
      expect(subject.configurable?).to eql(true)
    end
  end

  describe "needed_patterns" do
    let(:section) do
      {
        "default"  => "apparmor",
        "apparmor" => {
          "patterns" => "microos_apparmor"
        }
      }
    end

    it "returns the needed patterns for the selected LSM" do
      subject.propose_default
      expect(subject.needed_patterns).to eql(["microos_apparmor"])
    end

    it "returns an empty array if no LSM is selected" do
      expect(subject.needed_patterns).to eql([])
    end
  end

  describe "#save" do
    it "saves the selected LSM configuration" do
      subject.propose_default
      expect(subject.selected).to receive(:save).and_return(true)
      expect(subject.save).to eql(true)
    end

    context "when no LSM is selected" do
      it "returns false" do
        expect(subject.selected).to eq(nil)
        expect(subject.save).to eql(false)
      end
    end
  end
end

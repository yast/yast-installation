#! /usr/bin/rspec
# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require_relative "./test_helper"
require "installation/ssh_config"

describe Installation::SshConfig do
  describe ".import" do
    let(:root1_atime) { Time.now }
    let(:root2_atime) { Time.now - 1200 }

    before do
      Installation::SshConfig.all.clear
    end

    context "reading valid directories" do
      before do
        allow(File).to receive(:atime) do |path|
          path =~ /root2/ ? root2_atime : root1_atime
        end

        Installation::SshConfig.import(FIXTURES_DIR.join("root1"), "/dev/root1")
        Installation::SshConfig.import(FIXTURES_DIR.join("root2"), "/dev/root2")
      end

      it "reads the name of the systems with /etc/os-release" do
        expect(Installation::SshConfig.all).to include(
          an_object_having_attributes(
            device: "/dev/root1",
            system_name: "Operating system 1"
          )
        )
      end

      it "uses 'Linux' as name for systems without /etc/os-release" do
        expect(Installation::SshConfig.all).to include(
          an_object_having_attributes(
            device: "/dev/root2",
            system_name: "Linux"
          )
        )
      end

      it "stores the device name and keys' access time for all systems" do
        expect(Installation::SshConfig.all).to contain_exactly(
          an_object_having_attributes(
            device: "/dev/root1",
            keys_atime: root1_atime
          ),
          an_object_having_attributes(
            device: "/dev/root2",
            keys_atime: root2_atime
          )
        )
      end
    end

    it "ignores wrong root directories" do
      Installation::SshConfig.import(FIXTURES_DIR.join("root1/etc"), "dev")
      Installation::SshConfig.import("/non-existent", "dev")
      expect(Installation::SshConfig.all).to be_empty
    end
  end
end

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
require "installation/ssh_importer"
require "installation/ssh_config"

describe Installation::SshImporter do
  subject(:importer) { Installation::SshImporter.instance }

  describe "#add_config" do
    before do
      importer.configurations.clear
      importer.reset
    end

    it "stores the configuration if /etc/ssh contains keys" do
      importer.add_config(FIXTURES_DIR.join("root1"), "dev")
      expect(importer.configurations).to_not be_empty
    end

    it "does nothing if there are no keys in /etc/ssh" do
      importer.add_config(FIXTURES_DIR.join("root3"), "dev")
      expect(importer.configurations).to be_empty
    end

    it "does nothing if there is no /etc/ssh directory" do
      importer.add_config(FIXTURES_DIR.join("root1/etc"), "dev")
      expect(importer.configurations).to be_empty
    end

    it "does nothing if the root directory does not exist" do
      importer.add_config("/non-existent", "dev")
      expect(importer.configurations).to be_empty
    end

    context "reading several valid directories" do
      let(:now) { Time.now }
      let(:root2_atime) { Time.now - 60 }
      # We just want all config to have some keys, no matter which
      let(:keys) { [ instance_double(Installation::SshKey) ] }
      let(:root1) { instance_double("Installation::SshConfig", keys_atime: now - 1200, keys: keys) }
      let(:root2) { instance_double("Installation::SshConfig", keys_atime: now, keys: keys) }
      let(:root3) { instance_double("Installation::SshConfig", keys_atime: now - 60, keys: keys) }

      before do
        allow(Installation::SshConfig).to receive(:from_dir).with("root1_dir").and_return root1
        allow(Installation::SshConfig).to receive(:from_dir).with("root2_dir").and_return root2
        allow(Installation::SshConfig).to receive(:from_dir).with("root3_dir").and_return root3
      end

      it "stores the device name and configuration for all systems" do
        importer.add_config("root1_dir", "/dev/root1")
        importer.add_config("root2_dir", "/dev/root2")
        importer.add_config("root3_dir", "/dev/root3")

        expect(importer.configurations).to eq(
          "/dev/root1" => root1,
          "/dev/root2" => root2,
          "/dev/root3" => root3,
        )
      end

      it "sets #device to the most recently accessed configuration" do
        expect(importer.device).to be_nil
        importer.add_config("root1_dir", "/dev/root1")
        expect(importer.device).to eq "/dev/root1"
        importer.add_config("root2_dir", "/dev/root2")
        expect(importer.device).to eq "/dev/root2"
        importer.add_config("root3_dir", "/dev/root3")
        expect(importer.device).to eq "/dev/root2"
      end
    end
  end

  describe ".write" do
    let(:root1) { instance_double("Installation::SshConfig") }
    let(:root2) { instance_double("Installation::SshConfig") }

    before do
      allow(importer).to receive(:configurations).and_return(
        "/dev/root1" => root1,
        "/dev/root2" => root2
      )
    end

    context "if no device is selected" do
      it "writes nothing" do
        importer.device = nil

        expect(root1).to_not receive(:write_files)
        expect(root2).to_not receive(:write_files)

        importer.write("/somewhere")
      end
    end

    context "if a device is selected" do
      before do
        importer.device = "/dev/root2"
      end

      context "if #copy_config? is true" do
        before do
          importer.copy_config = true
        end

        it "writes the ssh keys of the choosen device" do
          expect(root2).to receive(:write_files) do |root_dir, flags|
            expect(flags[:write_keys]).to eq true
          end

          importer.write("/somewhere")
        end

        it "writes the config files of the choosen device" do
          expect(root2).to receive(:write_files) do |root_dir, flags|
            expect(flags[:write_config_files]).to eq true
          end

          importer.write("/somewhere")
        end

        it "does not write files from other devices" do
          allow(root2).to receive(:write_files)
          expect(root1).to_not receive(:write_files)

          importer.write("/somewhere")
        end
      end

      context "if #copy_config? is false" do
        before do
          importer.copy_config = false
        end

        it "writes the ssh keys of the choosen device" do
          expect(root2).to receive(:write_files) do |root_dir, flags|
            expect(flags[:write_keys]).to eq true
          end

          importer.write("/somewhere")
        end

        it "does not write the config files of the choosen device" do
          expect(root2).to receive(:write_files) do |root_dir, flags|
            expect(flags[:write_config_files]).to eq false
          end

          importer.write("/somewhere")
        end

        it "does not write files from other devices" do
          allow(root2).to receive(:write_files)
          expect(root1).to_not receive(:write_files)

          importer.write("/somewhere")
        end
      end
    end
  end
end

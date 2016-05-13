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
require "tmpdir"
require "fileutils"

describe Installation::SshConfig do
  describe ".import" do
    before do
      Installation::SshConfig.all.clear
    end

    context "reading valid directories" do
      let(:recent_root1_atime) { Time.now }
      let(:old_root1_atime) { Time.now - 60 }
      let(:root1_atime) { recent_root1_atime }
      let(:root2_atime) { Time.now - 1200 }

      before do
        allow(File).to receive(:atime) do |path|
          if path =~ /root2/
            root2_atime
          else
            path =~ /ssh_host_key$/ ? recent_root1_atime : old_root1_atime
          end
        end

        Installation::SshConfig.import(FIXTURES_DIR.join("root1"), "/dev/root1")
        Installation::SshConfig.import(FIXTURES_DIR.join("root2"), "/dev/root2")
      end

      let(:root1) { Installation::SshConfig.all.detect { |c| c.device == "/dev/root1" } }
      let(:root2) { Installation::SshConfig.all.detect { |c| c.device == "/dev/root2" } }

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

      it "stores the device name for all systems" do
        expect(Installation::SshConfig.all).to contain_exactly(
          an_object_having_attributes(device: "/dev/root1"),
          an_object_having_attributes(device: "/dev/root2")
        )
      end

      it "stores all the keys and files with their names" do
        expect(root1.config_files.map(&:name)).to contain_exactly(
          "moduli", "ssh_config", "sshd_config"
        )
        expect(root1.keys.map(&:name)).to contain_exactly(
          "ssh_host_dsa_key", "ssh_host_key"
        )
        expect(root2.config_files.map(&:name)).to contain_exactly(
          "known_hosts", "ssh_config", "sshd_config"
        )
        expect(root2.keys.map(&:name)).to contain_exactly(
          "ssh_host_ed25519_key", "ssh_host_key"
        )
      end

      it "stores the content of the config files" do
        expect(root1.config_files.map(&:content)).to contain_exactly(
          "root1: content of moduli file\n",
          "root1: content of ssh_config file\n",
          "root1: content of sshd_config file\n"
        )
      end

      it "stores the content of both files for the keys" do
        contents = root1.keys.map { |k| k.files.map(&:content) }
        expect(contents).to contain_exactly(
          ["root1: content of ssh_host_dsa_key file\n", "root1: content of ssh_host_dsa_key.pub file\n"],
          ["root1: content of ssh_host_key file\n", "root1: content of ssh_host_key.pub file\n"]
        )
      end

      it "uses the most recent file of each key to set #atime" do
        host_key = root1.keys.detect { |k| k.name == "ssh_host_key" }
        host_dsa_key = root1.keys.detect { |k| k.name == "ssh_host_dsa_key" }

        expect(host_key.atime).to eq recent_root1_atime
        expect(host_dsa_key.atime).to eq old_root1_atime
      end

      it "selects no file or key for exporting initially" do
        expect(root1.keys.any?(&:to_export?)).to eq false
        expect(root1.config_files.any?(&:to_export?)).to eq false
        expect(root2.keys.any?(&:to_export?)).to eq false
        expect(root2.config_files.any?(&:to_export?)).to eq false
      end
    end

    it "ignores wrong root directories" do
      Installation::SshConfig.import(FIXTURES_DIR.join("root1/etc"), "dev")
      Installation::SshConfig.import("/non-existent", "dev")
      expect(Installation::SshConfig.all).to be_empty
    end
  end

  describe ".export" do
    def permissions(file)
      sprintf("%o", File.stat(file).mode)[-3..-1]
    end

    around do |example|
      Installation::SshConfig.all.clear

      # Git does not preserve file permissions (only the executable bit),
      # so let's copy test/fixtures to a temporal directory and ensure
      # sensible permissions there
      Dir.mktmpdir do |dir|
        ::FileUtils.cp_r(FIXTURES_DIR.join("root1"), dir)
        Dir.glob("#{dir}/root1/etc/ssh/*").each do |file|
          if file.end_with?("_key") || file.end_with?("sshd_config") || file.end_with?("moduli")
            File.chmod(0600, file)
          else
            File.chmod(0644, file)
          end
        end
        Installation::SshConfig.import(File.join(dir, "root1"), "/dev/root1")
      end

      Dir.mktmpdir do |dir|
        @target_dir = dir
        example.run
      end
    end
    
    let(:config) { Installation::SshConfig.all.first }

    it "creates /etc/ssh/ if it does not exist" do
      Installation::SshConfig.export(@target_dir)
      expect(Dir.glob("#{@target_dir}/etc/*")).to eq ["#{@target_dir}/etc/ssh"]
    end

    it "reuses /etc/ssh if it's already there" do
      etc_dir = File.join(@target_dir, "etc", "ssh")
      ::FileUtils.mkdir_p(etc_dir)
      ::FileUtils.touch(File.join(etc_dir, "preexisting_file"))
      config.config_files.each { |f| f.to_export = true }

      Installation::SshConfig.export(@target_dir)

      files = Dir.glob("#{etc_dir}/*")
      expect(files.size).to eq(config.config_files.size + 1)
      expect(files).to include "#{etc_dir}/preexisting_file"
    end

    context "with some files and keys selected to export" do
      before do
        config.config_files.detect { |f| f.name == "moduli" }.to_export = true
        config.keys.detect { |f| f.name == "ssh_host_key" }.to_export = true
      end
      let(:ssh_dir) { File.join(@target_dir, "etc", "ssh") }

      it "writes the selected files" do
        Installation::SshConfig.export(@target_dir)

        target_content = Dir.glob("#{ssh_dir}/*")
        expect(target_content).to contain_exactly(
          "#{ssh_dir}/ssh_host_key", "#{ssh_dir}/ssh_host_key.pub", "#{ssh_dir}/moduli"
        )
      end

      it "preserves original permissions for files and keys" do
        config.config_files.detect { |f| f.name == "ssh_config" }.to_export = true
        Installation::SshConfig.export(@target_dir)

        expect(permissions("#{ssh_dir}/moduli")).to eq "600"
        expect(permissions("#{ssh_dir}/ssh_config")).to eq "644"
        expect(permissions("#{ssh_dir}/ssh_host_key")).to eq "600"
        expect(permissions("#{ssh_dir}/ssh_host_key.pub")).to eq "644"
      end
    
      it "backups config files found in the target directory" do
        ::FileUtils.mkdir_p(ssh_dir)
        ::FileUtils.touch(File.join(ssh_dir, "moduli"))

        Installation::SshConfig.export(@target_dir)

        expect(File.exist?(File.join(ssh_dir, "moduli.yast.orig"))).to eq true
      end
  
      it "writes the original content for each file" do
        Installation::SshConfig.export(@target_dir)

        expect(IO.read("#{ssh_dir}/moduli")).to eq(
          "root1: content of moduli file\n"
        )
        expect(IO.read("#{ssh_dir}/ssh_host_key")).to eq(
          "root1: content of ssh_host_key file\n"
        )
        expect(IO.read("#{ssh_dir}/ssh_host_key.pub")).to eq(
          "root1: content of ssh_host_key.pub file\n"
        )
      end
    end
  end

  describe "#keys_atime" do
    subject(:config) { Installation::SshConfig.new("name", "device") }
    let(:now) { Time.now }

    it "returns the access time of the most recently accessed key" do
      config.keys = [
        instance_double("Installation::SshKey", atime: now),
        instance_double("Installation::SshKey", atime: now + 1200),
        instance_double("Installation::SshKey", atime: now - 1200)
      ]
      expect(config.keys_atime).to eq(now + 1200)
    end

    it "returns nil if no keys has been read" do
      expect(config.keys_atime).to be_nil
    end
  end
end

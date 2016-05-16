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
  describe ".from_dir" do
    textdomain "installation"

    let(:recent_root1_atime) { Time.now }
    let(:old_root1_atime) { Time.now - 60 }
    let(:root1_dir) { FIXTURES_DIR.join("root1") }
    let(:root2_dir) { FIXTURES_DIR.join("root2") }

    before do
      # The ssh_host private key file is more recent than any other file
      allow(File).to receive(:atime) do |path|
        path =~ /ssh_host_key$/ ? recent_root1_atime : old_root1_atime
      end
    end

    it "reads the name of the systems with /etc/os-release" do
      root1 = described_class.from_dir(root1_dir)
      expect(root1.system_name).to eq "Operating system 1"
    end

    it "uses 'Linux' as name for systems without /etc/os-release" do
      root2 = described_class.from_dir(root2_dir)
      expect(root2.system_name).to eq _("Linux")
    end

    it "stores all the keys and files with their names" do
      root1 = described_class.from_dir(root1_dir)
      root2 = described_class.from_dir(root2_dir)

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
      root1 = described_class.from_dir(root1_dir)
      expect(root1.config_files.map(&:content)).to contain_exactly(
        "root1: content of moduli file\n",
        "root1: content of ssh_config file\n",
        "root1: content of sshd_config file\n"
      )
    end

    it "stores the content of both files for the keys" do
      root1 = described_class.from_dir(root1_dir)
      contents = root1.keys.map { |k| k.files.map(&:content) }
      expect(contents).to contain_exactly(
        ["root1: content of ssh_host_dsa_key file\n", "root1: content of ssh_host_dsa_key.pub file\n"],
        ["root1: content of ssh_host_key file\n", "root1: content of ssh_host_key.pub file\n"]
      )
    end

    it "uses the most recent file of each key to set #atime" do
      root1 = described_class.from_dir(root1_dir)
      host_key = root1.keys.detect { |k| k.name == "ssh_host_key" }
      host_dsa_key = root1.keys.detect { |k| k.name == "ssh_host_dsa_key" }

      expect(host_key.atime).to eq recent_root1_atime
      expect(host_dsa_key.atime).to eq old_root1_atime
    end
  end

  describe ".write_files" do
    def permissions(file)
      sprintf("%o", File.stat(file).mode)[-3..-1]
    end

    around do |example|
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
        @config = Installation::SshConfig.from_dir(File.join(dir, "root1"))
      end

      Dir.mktmpdir do |dir|
        @target_dir = dir
        example.run
      end
    end
    
    let(:ssh_dir) { File.join(@target_dir, "etc", "ssh") }

    it "creates /etc/ssh/ if it does not exist" do
      @config.write_files(@target_dir)
      expect(Dir.glob("#{@target_dir}/etc/*")).to eq ["#{@target_dir}/etc/ssh"]
    end

    it "reuses /etc/ssh if it's already there" do
      ::FileUtils.mkdir_p(ssh_dir)
      ::FileUtils.touch(File.join(ssh_dir, "preexisting_file"))

      @config.write_files(@target_dir, write_keys: false)

      files = Dir.glob("#{ssh_dir}/*")
      expect(files.size).to eq(@config.config_files.size + 1)
      expect(files).to include "#{ssh_dir}/preexisting_file"
    end

    it "writes all the files by default" do
      @config.write_files(@target_dir)

      target_content = Dir.glob("#{ssh_dir}/*")
      expect(target_content).to contain_exactly(
        "#{ssh_dir}/ssh_host_key", "#{ssh_dir}/ssh_host_key.pub",
        "#{ssh_dir}/ssh_host_dsa_key", "#{ssh_dir}/ssh_host_dsa_key.pub",
        "#{ssh_dir}/moduli", "#{ssh_dir}/ssh_config", "#{ssh_dir}/sshd_config"
      )
    end

    it "writes only the key files if write_config_files is false" do
      @config.write_files(@target_dir, write_config_files: false)

      target_content = Dir.glob("#{ssh_dir}/*")
      expect(target_content).to contain_exactly(
        "#{ssh_dir}/ssh_host_key", "#{ssh_dir}/ssh_host_key.pub",
        "#{ssh_dir}/ssh_host_dsa_key", "#{ssh_dir}/ssh_host_dsa_key.pub"
      )
    end

    it "writes only the config files if write_keys is false" do
      @config.write_files(@target_dir, write_keys: false)

      target_content = Dir.glob("#{ssh_dir}/*")
      expect(target_content).to contain_exactly(
        "#{ssh_dir}/moduli", "#{ssh_dir}/ssh_config", "#{ssh_dir}/sshd_config"
      )
    end

    it "preserves original permissions for files and keys" do
      @config.write_files(@target_dir)

      expect(permissions("#{ssh_dir}/moduli")).to eq "600"
      expect(permissions("#{ssh_dir}/ssh_config")).to eq "644"
      expect(permissions("#{ssh_dir}/ssh_host_key")).to eq "600"
      expect(permissions("#{ssh_dir}/ssh_host_key.pub")).to eq "644"
    end
    
    it "backups config files found in the target directory" do
      ::FileUtils.mkdir_p(ssh_dir)
      ::FileUtils.touch(File.join(ssh_dir, "moduli"))

      @config.write_files(@target_dir)

      expect(File.exist?(File.join(ssh_dir, "moduli.yast.orig"))).to eq true
    end
  
    it "writes the original content for each file" do
      @config.write_files(@target_dir)

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

  describe "#keys_atime" do
    subject(:config) { ::Installation::SshConfig.new("name") }
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

#! /usr/bin/env rspec

require_relative "./test_helper"
require "installation/ssh_key"

describe Installation::SshKey do
  subject(:sshkey) { Installation::SshKey.new("ssh_host_ed25519_key") }

  describe "#write_files" do
    before do
      sshkey.read_files(FIXTURES_DIR.join("root2/etc/ssh",subject.name).to_s)
    end

    it "writes ssh keys with the right permissions" do
      expect(IO).to receive(:write).twice
      expect(File).to receive(:chmod).with(0600,
        "/mnt/etc/ssh/ssh_host_ed25519_key")
      expect(File).to receive(:chmod).with(33188,
        "/mnt/etc/ssh/ssh_host_ed25519_key.pub")
      sshkey.write_files("/mnt/etc/ssh")
    end
  end
end

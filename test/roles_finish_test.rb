#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/clients/roles_finish"
require "fileutils"

describe ::Installation::Clients::RolesFinish do
  MASTER_CONF          = FIXTURES_DIR.join("minion.d/master.conf").freeze
  MASTER_CONF_EXISTENT = FIXTURES_DIR.join("minion.d/master.conf_existent").freeze
  MASTER_CONF_EXPECTED = FIXTURES_DIR.join("minion.d/master.conf_expected").freeze

  let(:master_conf) { ::Installation::CFA::MinionMasterConf.new }
  let(:master_conf_path) { MASTER_CONF }

  after do
    FileUtils.remove_file(MASTER_CONF, true)
  end

  before do
    allow(Yast::Stage).to receive(:initial).and_return(true)
    allow(subject).to receive(:master).and_return("salt_controller")
    stub_const("Installation::CFA::MinionMasterConf::PATH", master_conf_path)
  end

  describe "#title" do
    it "returns string with title" do
      expect(subject.title).to be_a ::String
    end
  end

  describe "#write" do
    it "calls finish handler for the current role" do
      expect(::Installation::SystemRole).to receive(:current).and_return("worker_role")
      expect(::Installation::SystemRole).to receive(:finish).with("worker_role")

      subject.write
    end
  end
end

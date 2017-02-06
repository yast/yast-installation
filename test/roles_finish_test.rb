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
    context "when the current role is 'worker'" do
      context "when the minion master.conf file not exists" do
        it "creates the file with master: as the controller node location" do
          allow(subject).to receive(:current_role).and_return("worker_role")

          subject.write

          expect(File.read(master_conf_path)).to eq(File.read(MASTER_CONF_EXPECTED))
        end
      end

      context "when the minion master.conf file exists" do
        before do
          FileUtils.cp(MASTER_CONF_EXISTENT, MASTER_CONF)
        end

        it "modifies master: with the controller node location" do
          expect(File.read(master_conf_path)).not_to eq(File.read(MASTER_CONF_EXPECTED))
          allow(subject).to receive(:current_role).and_return("worker_role")

          subject.write

          expect(File.read(master_conf_path)).to eq(File.read(MASTER_CONF_EXPECTED))
        end
      end
    end
  end
end

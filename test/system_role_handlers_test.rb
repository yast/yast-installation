#! /usr/bin/env rspec

require_relative "./test_helper"
require "installation/system_role"
require "installation/system_roles/handlers"

describe Installation::SystemRoleHandlers::WorkerRoleFinish do
  let(:role) { instance_double("::Installation::SystemRole") }
  let(:conf) do
    instance_double("::Installation::CFA::MinionMasterConf", load: true, save: true)
  end

  before do
    allow(::Installation::SystemRole).to receive("find")
      .with("worker_role").and_return(role)
    allow(::Installation::CFA::MinionMasterConf).to receive(:new).and_return(conf)
  end

  describe ".run" do
    context "if the worker role controller node location contains dashes" do
      it "surrounds the url with single quotes before save" do
        expect(role).to receive(:[]).with("controller_node").and_return("controller-url")
        expect(conf).to receive(:master=).with("'controller-url'")
        described_class.run
      end

    end

    context "if the worker role controller node location does not contain dashes" do
      it "saves the url as defined" do
        expect(role).to receive(:[]).with("controller_node").and_return("controller")
        expect(conf).to receive(:master=).with("controller")
        described_class.run
      end
    end

    it "saves the controller node location into the minion master.conf file" do
      expect(role).to receive(:[]).with("controller_node").and_return("controller")
      expect(conf).to receive(:master=).with("controller")
      expect(conf).to receive(:save)

      described_class.run
    end
  end
end

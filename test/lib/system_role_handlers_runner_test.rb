#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/system_role_handlers_runner"

describe Installation::SystemRoleHandlersRunner do
  subject(:runner) { Installation::SystemRoleHandlersRunner.new }

  describe "#finish" do
    let(:handler) { double("handler") }
    before do
      stub_const("::Installation::SystemRoleHandlers::TestRoleFinish", handler)
      allow(subject).to receive(:require).with("installation/system_role_handlers/test_role_finish")
    end

    it "runs the handler's 'run' method" do
      expect(handler).to receive(:run)
      runner.finish("test_role")
    end

    context "when handler file is not found" do
      before do
        allow(subject).to receive(:require).and_call_original
      end

      it "logs the error" do
        expect(runner.log).to receive(:info).with(/not found/)
        runner.finish("unknown_role")
      end
    end

    context "when handler class is not defined" do
      before do
        allow(subject).to receive(:require).with("installation/system_role_handlers/undefined_role_finish")
      end

      it "logs the error" do
        expect(runner.log).to receive(:info).with(/not defined/)
        runner.finish("undefined_role")
      end
    end
  end
end

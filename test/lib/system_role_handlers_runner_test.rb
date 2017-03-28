#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/system_role_handlers_runner"

describe Installation::SystemRoleHandlersRunner do
  subject(:runner) { Installation::SystemRoleHandlersRunner.new }

  describe "#finish" do
    let(:handler_class) { double("HandlerClass") }
    let(:handler) { double("HandlerInstance") }

    before do
      stub_const("Y2SystemRoleHandlers::TestRoleFinish", handler_class)
      allow(handler_class).to receive(:new).and_return(handler)
      allow(runner).to receive(:require).with("y2system_role_handlers/test_role_finish")
    end

    it "runs the handler's 'run' method" do
      expect(handler).to receive(:run)
      runner.finish("test_role")
    end

    context "when handler file is not found" do
      before do
        allow(runner).to receive(:require).and_call_original
      end

      it "logs the error" do
        expect(runner.log).to receive(:info).with(/not found/)
        runner.finish("unknown_role")
      end
    end

    context "when handler class is not defined" do
      before do
        allow(runner).to receive(:require).with("y2system_role_handlers/undefined_role_finish")
      end

      it "logs the error" do
        expect(runner.log).to receive(:info).with(/not defined/)
        runner.finish("undefined_role")
      end
    end
  end
end

#! /usr/bin/env rspec

require_relative "../../test_helper"
require "installation/system_role_handlers/dashboard_role_finish"

describe Installation::SystemRoleHandlers::DashboardRoleFinish do
  subject(:handler) { Installation::SystemRoleHandlers::DashboardRoleFinish.new }

  describe "#run" do
    it "runs the activation script" do
      expect(Yast::Execute).to receive(:on_target).with(/activate.sh/)
      handler.run
    end
  end
end

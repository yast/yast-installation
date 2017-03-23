#! /usr/bin/env rspec

require_relative "../../test_helper"
require "installation/system_role"
require "installation/system_role_handlers/dashboard_role_finish"

describe Installation::SystemRoleHandlers::DashboardRoleFinish do
  subject(:handler) { Installation::SystemRoleHandlers::DashboardRoleFinish.new }

  describe "#run" do
    let(:script_exists) { true }

    before do
      allow(Yast::FileUtils).to receive(:Exists).with(/activate.sh/)
        .and_return(script_exists)
    end

    it "runs the activation script" do
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Term.new(".target.bash_output"), /activate.sh/)
        .and_return("exit" => 0)
      handler.run
    end

    context "when the script is not found" do
      let(:script_exists) { false }

      it "informs the user" do
        expect(Yast::Popup).to receive(:Error)
        handler.run
      end
    end

    context "when the script fails" do
      it "shows the error to the user" do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Term.new(".target.bash_output"), /activate.sh/)
          .and_return("exit" => 1, "stderr" => "Some error")
        expect(Yast::Popup).to receive(:LongError)
          .with(/Some error/)
        handler.run
      end
    end
  end
end

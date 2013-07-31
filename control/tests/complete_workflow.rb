# encoding: utf-8

# This client starts a custom  autoinstallation workflow using
# a stripped down control file and an autoyast profile.
# first argument is the autoyast profile, second is the workflow
# control file.
# see a test workflow control file in the same directory
module Yast
  class CompleteWorkflowClient < Client
    def main
      Yast.import "UI"
      Yast.import "XML"
      Yast.import "Profile"
      Yast.import "AutoInstall"
      Yast.import "ProductControl"

      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Stage"

      Mode.SetTest("test")

      @control = ""
      @profile = ""
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @control = Convert.to_string(WFM.Args(0))
      end

      ProductControl.custom_control_file = @control
      if !ProductControl.Init
        Builtins.y2error(
          "control file %1 not found",
          ProductControl.custom_control_file
        )
        return :abort
      end


      Wizard.OpenNextBackStepsDialog
      @stage_mode = [{ "stage" => "normal", "mode" => Mode.mode }]
      #stage_mode = add(stage_mode, $["stage": "continue",  "mode": Mode::mode () ] );
      ProductControl.AddWizardSteps(@stage_mode)

      @ret = ProductControl.Run


      UI.CloseDialog
      @ret
    end
  end
end

Yast::CompleteWorkflowClient.new.main

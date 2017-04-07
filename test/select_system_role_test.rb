#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/select_system_role"
Yast.import "ProductControl"

describe ::Installation::SelectSystemRole do
  subject { Installation::SelectSystemRole.new }

  before do
    allow(Yast::ProductControl).to receive(:GetTranslatedText) do |s|
      "Lorem Ipsum #{s}"
    end

    allow(Yast::UI).to receive(:ChangeWidget)

    Installation::SystemRole.clear # Clear system roles cache
  end

  describe "#run" do
    before do
      # reset previous test
      subject.class.original_role_id = nil

      allow(Yast::ProductFeatures).to receive(:ClearOverlay)
      allow(Yast::ProductFeatures).to receive(:SetOverlay) # .with
    end

    context "when no roles are defined" do
      before do
        allow(Yast::ProductControl).to receive(:system_roles)
          .and_return([])
      end

      it "does not display dialog, and returns :auto" do
        expect(Yast::Wizard).to_not receive(:SetContents)
        expect(subject.run).to eq(:auto)
      end
    end

    context "when some roles are defined" do
      let(:control_file_roles) do
        [
          { "id" => "foo", "partitioning" => { "format" => true } },
          { "id" => "bar", "software" => { "desktop" => "knome" }, "additional_dialogs" => "a,b" }
        ]
      end

      before do
        allow(Yast::ProductControl).to receive(:system_roles)
          .and_return(control_file_roles)
      end

      it "displays dialog, and sets ProductFeatures on Next" do
        allow(Yast::Wizard).to receive(:SetContents)
        allow(Yast::UI).to receive(:UserInput)
          .and_return(:next)
        allow(Yast::UI).to receive(:QueryWidget)
          .with(Id(:roles), :CurrentButton).and_return("foo")

        expect(Yast::ProductFeatures).to receive(:ClearOverlay)
        expect(Yast::ProductFeatures).to receive(:SetOverlay) # .with

        expect(subject.run).to eq(:next)
      end

      it "displays dialog, and leaves ProductFeatures on Back" do
        allow(Yast::Wizard).to receive(:SetContents)
        allow(Yast::UI).to receive(:UserInput)
          .and_return(:back)
        expect(Yast::ProductFeatures).to receive(:ClearOverlay)
        expect(Yast::ProductFeatures).to_not receive(:SetOverlay)

        expect(subject.run).to eq(:back)
      end

      context "when a role contains additional dialogs" do
        it "shows the first dialog when going forward" do
          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return(:next)
          allow(Yast::UI).to receive(:QueryWidget)
            .with(Id(:roles), :CurrentButton).and_return("bar")

          allow(Yast::WFM).to receive(:CallFunction).and_return(:next)
          expect(Yast::WFM).to receive(:CallFunction).with("a", anything).and_return(:next)

          expect(subject.run).to eq(:next)
        end

        it "shows the last dialog when going back" do
          subject.class.original_role_id = "bar"
          allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)
          expect(Yast::Wizard).to_not receive(:SetContents)
          expect(Yast::UI).to_not receive(:UserInput)
          expect(Yast::UI).to_not receive(:QueryWidget)

          expect(Yast::WFM).to receive(:CallFunction).with("b", anything).and_return(:next)

          expect(subject.run).to eq(:next)
        end
      end

      context "when re-selecting the same role" do
        it "just proceeds without a popup" do
          subject.class.original_role_id = "foo"

          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return(:next)
          allow(Yast::UI).to receive(:QueryWidget)
            .with(Id(:roles), :CurrentButton).and_return("foo")

          expect(Yast::Popup).to_not receive(:ContinueCancel)

          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to receive(:SetOverlay)

          expect(subject.run).to eq(:next)
        end
      end

      context "when re-selecting a different role" do
        it "displays a popup, and proceeds if Continue is answered" do
          subject.class.original_role_id = "bar"

          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return(:next)
          allow(Yast::UI).to receive(:QueryWidget)
            .with(Id(:roles), :CurrentButton).and_return("foo")

          expect(Yast::Popup).to receive(:ContinueCancel)
            .and_return(true)

          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to receive(:SetOverlay)

          expect(subject.run).to eq(:next)
        end

        it "displays a popup, and does not proceed if Cancel is answered" do
          subject.class.original_role_id = "bar"

          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return(:next, :back)
          allow(Yast::UI).to receive(:QueryWidget)
            .with(Id(:roles), :CurrentButton).and_return("foo")

          expect(Yast::Popup).to receive(:ContinueCancel)
            .and_return(false)
          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to_not receive(:SetOverlay)

          expect(subject.run).to eq(:back)
        end
      end
    end
  end

  describe "#dialog_content" do
    let(:system_roles) do # 5 lines are needed
      [
        ::Installation::SystemRole.new(id: "role1", description: "Line 1\nLine 2"),
        ::Installation::SystemRole.new(id: "role2", description: "Line 1")
      ]
    end

    let(:textmode) { true }
    let(:height) { 25 }
    let(:display_info) do
      {
        "Height" => height,
        "Width"  => 80
      }
    end
    let(:intro_text) { "Some introductory\ntest" }

    before do
      allow(Yast::UI).to receive(:TextMode).and_return(textmode)
      allow(Yast::UI).to receive(:GetDisplayInfo).and_return(display_info)
      allow(::Installation::SystemRole).to receive(:all).and_return(system_roles)
      allow(Yast::ProductControl).to receive(:GetTranslatedText).with("roles_text")
        .and_return(intro_text)
    end

    context "when there's enough room" do
      it "shows intro, separations, radio buttons and roles descriptions" do
        expect(subject).to receive(:Label).with(intro_text) # intro
        expect(subject).to receive(:VSpacing).with(1) # margin
        expect(subject).to receive(:RadioButton).with(anything, system_roles[0].label) # rol label
        expect(subject).to receive(:Label).with(/#{system_roles[0].description}/) # rol description
        expect(subject).to receive(:VSpacing).with(2) # separator
        expect(subject).to receive(:RadioButton).with(anything, system_roles[1].label) # rol label
        expect(subject).to receive(:Label).with(/#{system_roles[1].description}/) # rol description
        subject.dialog_content
      end
    end

    context "when there is enough room just reducing separations" do
      let(:height) { 14 }

      it "reduces separation" do
        expect(subject).to receive(:VSpacing).with(1).twice # margin + separator
        subject.dialog_content
      end
    end

    context "when there is not enough room even reducing separations" do
      let(:height) { 10 }

      it "reduces separation and omits descriptions" do
        expect(subject).to_not receive(:Label).with(/#{system_roles[0].description}/)
        expect(subject).to_not receive(:Label).with(/#{system_roles[1].description}/)
        subject.dialog_content
      end
    end

    context "when there is not enough room even omitting descriptions" do
      let(:height) { 8 }

      it "reduces separation, omits descriptions and removes the margin" do
        expect(subject).to receive(:Label).with(intro_text) # intro
        expect(subject).to_not receive(:VSpacing)
        subject.dialog_content
      end
    end

    context "when there is not enough room even removing the margin" do
      let(:height) { 7 }

      it "reduces separation, omits description and hides the introductory text" do
        expect(subject).to_not receive(:Label).with(intro_text) # intro
        expect(subject).to_not receive(:VSpacing)
        subject.dialog_content
      end
    end

    context "when not in textmode" do
      let(:textmode) { false }

      it "shows intro, separations, radio buttons and roles descriptions" do
        expect(subject).to receive(:Label).with(intro_text) # intro
        expect(subject).to receive(:VSpacing).with(2) # margin
        expect(subject).to receive(:RadioButton).with(anything, system_roles[0].label) # rol label
        expect(subject).to receive(:Label).with(/#{system_roles[0].description}/) # rol description
        expect(subject).to receive(:VSpacing).with(2) # separator
        expect(subject).to receive(:RadioButton).with(anything, system_roles[1].label) # rol label
        expect(subject).to receive(:Label).with(/#{system_roles[1].description}/) # rol description
        subject.dialog_content
      end
    end
  end
end

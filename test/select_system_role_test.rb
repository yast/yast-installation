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

    allow(Installation::SystemRole).to receive(:select)
    allow(Yast::UI).to receive(:ChangeWidget)
    allow(Yast::Language).to receive(:language).and_return("en_US")

    Installation::SystemRole.clear # Clear system roles cache
  end

  describe "#run" do
    before do
      allow(Yast::ProductFeatures).to receive(:ClearOverlay)
      allow(Yast::ProductFeatures).to receive(:SetOverlay)
      allow(Yast::Packages).to receive(:Reset)
      allow(Yast::Packages).to receive(:SelectSystemPatterns)
      allow(Yast::Packages).to receive(:SelectSystemPackages)
      allow(Installation::SystemRole).to receive(:current)
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

    context "when single role is defined" do
      let(:additional_dialogs) { "" }
      let(:control_file_roles) do
        [
          { "id" => "bar", "order" => "200",
            "software" => { "desktop" => "knome" }, "additional_dialogs" => additional_dialogs }
        ]
      end

      before do
        allow(Yast::ProductControl).to receive(:system_roles)
          .and_return(control_file_roles)
        allow(Yast::WFM).to receive(:CallFunction).and_return(:next)
        allow(Installation::SystemRole).to receive(:select).with("bar")
          .and_return(Installation::SystemRole.new(id: "bar", order: 200))
      end

      it "(re)sets ProductFeatures" do
        expect(Yast::ProductFeatures).to receive(:ClearOverlay)
        expect(Yast::ProductFeatures).to receive(:SetOverlay)

        subject.run
      end

      context "and going forward" do
        before do
          allow(Yast::UI).to receive(:UserInput).and_return(:next)
        end

        it "does not display dialog" do
          expect(Yast::Wizard).to_not receive(:SetContents)
          expect(Yast::UI).to_not receive(:UserInput)
          expect(Yast::UI).to_not receive(:QueryWidget)

          subject.run
        end

        it "returns :next" do
          expect(subject.run).to be(:next)
        end

        context "and there are additional dialogs" do
          let(:additional_dialogs) { "a,b" }

          it "shows the first one" do
            expect(Yast::WFM).to receive(:CallFunction).with("a", anything).and_return(:next)

            subject.run
          end
        end
      end

      context "and going back" do
        before do
          allow(Installation::SystemRole).to receive(:current).and_return("bar")
          allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)
          allow(Yast::UI).to receive(:UserInput).and_return(:back)
        end

        it "does not display dialog" do
          expect(Yast::Wizard).to_not receive(:SetContents)
          expect(Yast::UI).to_not receive(:UserInput)
          expect(Yast::UI).to_not receive(:QueryWidget)

          subject.run
        end

        it "returns :back" do
          expect(subject.run).to be(:back)
        end

        context "and there are additional dialogs" do
          let(:additional_dialogs) { "a,b" }

          it "shows the last one" do
            allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)
            expect(Yast::WFM).to receive(:CallFunction).with("b", anything).and_return(:next)

            subject.run
          end
        end
      end
    end

    context "when some roles are defined" do
      let(:control_file_roles) do
        [
          { "id" => "foo", "order" => "100", "partitioning" => { "format" => true } },
          { "id" => "bar", "order" => "200",
            "software" => { "desktop" => "knome" }, "additional_dialogs" => "a,b" }
        ]
      end

      before do
        allow(Yast::ProductControl).to receive(:system_roles)
          .and_return(control_file_roles)
        allow(Installation::SystemRole).to receive(:select).with("foo")
          .and_return(Installation::SystemRole.new(id: "foo", order: 100))
        allow(Installation::SystemRole).to receive(:select).with("bar")
          .and_return(Installation::SystemRole.new(id: "bar", order: 200))
      end

      it "displays dialog, and sets ProductFeatures on Next" do
        allow(Yast::Wizard).to receive(:SetContents)
        allow(Yast::UI).to receive(:UserInput)
          .and_return("foo", :next)

        expect(Yast::ProductFeatures).to receive(:ClearOverlay)
        expect(Yast::ProductFeatures).to receive(:SetOverlay)

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
            .and_return("bar", :next)

          allow(Yast::WFM).to receive(:CallFunction).and_return(:next)
          expect(Yast::WFM).to receive(:CallFunction).with("a", anything).and_return(:next)

          expect(subject.run).to eq(:next)
        end

        it "shows the last dialog when going back" do
          allow(Installation::SystemRole).to receive(:current).and_return("bar")
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
          allow(Installation::SystemRole).to receive(:current).and_return("foo")
          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return("foo", :next)

          expect(Yast::Popup).to_not receive(:ContinueCancel)

          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to receive(:SetOverlay)

          expect(subject.run).to eq(:next)
        end
      end

      context "when re-selecting a different role" do
        it "displays a popup, and proceeds if Continue is answered" do
          allow(Installation::SystemRole).to receive(:current).and_return("bar")
          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return("foo", :next)

          expect(Yast::Popup).to receive(:ContinueCancel)
            .and_return(true)

          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to receive(:SetOverlay)

          expect(subject.run).to eq(:next)
        end

        it "displays a popup, and does not proceed if Cancel is answered" do
          allow(Installation::SystemRole).to receive(:current).and_return("bar")
          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return("foo", :next, :back)

          expect(Yast::Popup).to receive(:ContinueCancel)
            .and_return(false)
          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to_not receive(:SetOverlay)

          expect(subject.run).to eq(:back)
        end
      end

      context "when no roles is selected" do
        it "shows error and does not continue" do
          allow(Yast::Wizard).to receive(:SetContents)
          allow(Yast::UI).to receive(:UserInput)
            .and_return(:next, :back)
          allow(Yast::UI).to receive(:QueryWidget)
            .with(Id(:roles), :CurrentButton).and_return(nil)
          allow(Installation::SystemRole).to receive(:default?)
            .and_return(false)

          expect(Yast::Popup).to receive(:Error)
          expect(Yast::ProductFeatures).to receive(:ClearOverlay)
          expect(Yast::ProductFeatures).to_not receive(:SetOverlay)

          expect(subject.run).to eq(:back)
        end
      end
    end
  end
end

#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/clients/inst_casp_overview"

Yast.import "CWM"
Yast.import "Language"
Yast.import "Mode"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "Wizard"

# stub tune widgets used in dialog
require "cwm/widget"

module Tune
  module Widgets
    class SystemInformation < CWM::PushButton
      def label
        "System Information"
      end
    end
  end
end

module Registration
  module Widgets
    class RegistrationCode < CWM::InputField
      def label
        "Registration code"
      end
    end
  end
end

module Users
  class PasswordWidget < CWM::CustomWidget
    def initialize(little_space: true)
    end

    def label
      "Password"
    end
  end
end

module Y2Country
  module Widgets
    class KeyboardSelectionCombo < CWM::ComboBox
      def initialize(_language)
      end

      def label
        "Keyboard"
      end
    end
  end
end

describe ::Installation::InstCaspOverview do
  describe "#run" do
    before do
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::Pkg).to receive(:SetPackageLocale)
      allow(Yast::CWM).to receive(:show).and_return(:next)
      allow(Yast::Language).to receive(:language).and_return("en_US")
      allow(Yast::WFM).to receive(:CallFunction).and_return({})
      allow(Yast::WFM).to receive(:CallFunction)
        .with("inst_doit", []).and_return(:next)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/info.txt").and_return(false)
    end

    it "sets package locale same as Language" do
      expect(Yast::Pkg).to receive(:SetPackageLocale).with(Yast::Language.language)

      subject.run
    end

    it "creates wizard dialog in normal mode" do
      allow(Yast::Mode).to receive(:normal).and_return(true)

      expect(Yast::Wizard).to receive(:CreateDialog)

      subject.run
    end

    it "closed wizard dialog in normal mode" do
      allow(Yast::Mode).to receive(:normal).and_return(true)

      expect(Yast::Wizard).to receive(:CloseDialog)

      subject.run
    end

    it "shows CWM widgets" do
      allow(Yast::Mode).to receive(:normal).and_return(true)

      expect(Yast::CWM).to receive(:show).and_return(:next)

      subject.run
    end

    it "adds caasp specific services to be enabled" do
      subject.run

      expect(::Installation::Services.enabled).to include("cloud-init")
    end

    it "displays the /info.txt file if it exists" do
      expect(File).to receive(:exist?).with("/info.txt").and_return(true)
      expect(Yast::InstShowInfo).to receive(:show_info_txt).with("/info.txt").and_return(true)
      expect(Yast::CWM).to receive(:show).and_return(:next)

      subject.run
    end

    it "does not try displaying the /info.txt file if it does not exist" do
      expect(File).to receive(:exist?).with("/info.txt").and_return(false)
      expect(Yast::InstShowInfo).to_not receive(:show_info_txt)
      expect(Yast::CWM).to receive(:show).and_return(:next)

      subject.run
    end
  end
end

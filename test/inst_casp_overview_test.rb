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

describe ::Installation::InstCaspOverview do
  describe "#run" do
    before do
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::Pkg).to receive(:SetPackageLocale)
      allow(Yast::CWM).to receive(:show).and_return(:next)
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

    it "shows CWM widgets again if it returns redraw event" do
      allow(Yast::Mode).to receive(:normal).and_return(true)

      expect(Yast::CWM).to receive(:show).twice.and_return(:redraw, :next)

      subject.run
    end
  end
end

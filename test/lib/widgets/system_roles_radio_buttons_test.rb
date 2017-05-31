#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/system_roles_radio_buttons"

describe Installation::Widgets::SystemRolesRadioButtons do
  subject(:widget) { Installation::Widgets::SystemRolesRadioButtons.new }
  let(:default) { nil }

  describe "#store" do
    before do
      allow(widget).to receive(:value).and_return(value)
      allow(widget).to receive(:store_orig)
    end

    context "when value is custom" do
      let(:value) { "custom" }

      it "do not set any default desktop" do
        expect(Installation::CustomPatterns).to receive(:show=).with(true)
        expect(Yast::DefaultDesktop).to receive(:SetDesktop).with(nil)
        widget.store
      end
    end

    context "when value is not custom" do
      let(:value) { "server" }

      it "resets default desktop" do
        expect(Installation::CustomPatterns).to receive(:show=).with(false)
        expect(Yast::DefaultDesktop).to receive(:ForceReinit)
        widget.store
      end
    end
  end

  describe "#handle" do
    it "selects the system role according to the current value" do
      allow(Installation::SystemRole).to receive(:select)

      expect(widget.handle).to eql(default)
    end

    it "returns nil" do
      allow(Installation::SystemRole).to receive(:select)

      expect(widget.handle).to eql(nil)
    end
  end

  describe "#init" do
    it "initializes the widget with the current system role" do
      allow(Installation::SystemRole).to receive(:current).and_return("server")
      expect(widget).to receive(:value=).with("server")

      expect(widget.init).to eql("server")
    end
  end

  describe "#validate" do
    let(:value) { nil }

    before do
      allow(widget).to receive(:value).and_return(value)
    end

    context "when no option has been selected" do
      it "opens an error popup" do
        expect(Yast::Popup).to receive(:Error)

        expect(widget.validate).to eql(false)
      end

      it "returns false" do
        expect(Yast::Popup).to receive(:Error)

        expect(widget.validate).to eql(false)
      end
    end

    context "when the widget has some value selected" do
      let(:value) { "server" }

      it "returns true" do
        expect(Yast::Popup).to_not receive(:Error)

        expect(widget.validate).to eql(true)
      end
    end
  end
end

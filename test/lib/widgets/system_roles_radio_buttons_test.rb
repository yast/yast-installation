#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/system_roles_radio_buttons"

describe Installation::Widgets::SystemRolesRadioButtons do
  subject(:widget) { Installation::Widgets::SystemRolesRadioButtons.new }

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
end

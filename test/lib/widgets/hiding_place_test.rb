#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/hiding_place"

describe ::Installation::Widgets::HidingPlace do
  subject(:place) { ::Installation::Widgets::HidingPlace.new(widget) }
  let(:widget) { DummyWidget.new }

  class DummyWidget < CWM::InputField
    def label
      "Label"
    end

    def init
      @value = "current"
    end

    attr_accessor :value
  end

  describe "#show" do
    it "shows the widget" do
      expect(place).to receive(:replace).with(widget)
      place.show
    end

    it "restores the previous value" do
      widget.value = "updated"
      place.hide
      place.show
      expect(widget.value).to eq("updated")
    end
  end

  describe "#hide" do
    it "hides the widget" do
      expect(place).to receive(:replace).with(CWM::Empty)
      place.hide
    end
  end

  describe "#store" do
    it "restores the previous value" do
      widget.value = "original"
      place.store
      widget.value = "forced"
      place.show
      expect(widget.value).to eq("original")
    end
  end
end

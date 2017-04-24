#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/system_role"

describe ::Installation::Widgets::SystemRole do
  subject(:widget) do
    ::Installation::Widgets::SystemRole.new(controller_node_widget, ntp_server_widget)
  end

  let(:controller_node_widget) { double("controller_node_widget") }
  let(:ntp_server_widget) { double("ntp_server_widget") }
  Yast::ProductControl.GetTranslatedText("roles_caption")

  describe "#label" do
    before do
      allow(Yast::ProductControl).to receive(:GetTranslatedText)
        .with("roles_caption").and_return("LABEL")
    end

    it "returns the label defined in the product's control file" do
      expect(widget.label).to eq("LABEL")
    end
  end

  describe "#handle" do
    let(:value) { "" }

    before do
      allow(widget).to receive(:value).and_return(value)
    end

    it "returns nil" do
      allow(ntp_server_widget).to receive(:hide)
      allow(controller_node_widget).to receive(:hide)
      expect(widget.handle).to be_nil
    end

    context "when value is 'worker_role'" do
      let(:value) { "worker_role" }

      it "only shows the controller node widget" do
        expect(ntp_server_widget).to receive(:hide)
        expect(controller_node_widget).to receive(:show)
        widget.handle
      end
    end

    context "when value is 'dashboard_role'" do
      let(:value) { "dashboard_role" }

      it "only shows the NTP server widget" do
        expect(ntp_server_widget).to receive(:show)
        expect(controller_node_widget).to receive(:hide)
        widget.handle
      end
    end

    context "when value is not 'worker_role' nor 'dashboard_role'" do
      let(:value) { "none_role" }

      it "hides all widgets" do
        expect(ntp_server_widget).to receive(:hide)
        expect(controller_node_widget).to receive(:hide)
        widget.handle
      end
    end
  end
end

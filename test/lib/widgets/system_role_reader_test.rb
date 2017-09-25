#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/system_role_reader"

describe ::Installation::Widgets::SystemRoleReader do
  class DummySystemRoleReader
    include Yast::Logger
    include ::Installation::Widgets::SystemRoleReader
  end

  subject { DummySystemRoleReader.new }

  let(:default_role) do
    ::Installation::SystemRole.new(id: "default", order: "100", label: "Default Role", description: "Role description")
  end

  let(:alt_role) do
    ::Installation::SystemRole.new(id: "alt", order: "200", label: "Alternate Role", description: "Role description")
  end

  before do
    allow(::Installation::SystemRole).to receive(:all).and_return([default_role, alt_role])
  end

  describe "#default" do
    before do
      allow(::Installation::SystemRole).to receive(:default?).and_return(default?)
    end

    context "when a default is expected" do
      let(:default?) { true }

      it "returns the default role" do
        expect(subject.default).to eq(default_role.id)
      end
    end

    context "when not default is expected" do
      let(:default?) { false }

      it "returns nil" do
        expect(subject.default).to be_nil
      end
    end
  end

  describe "#init" do
    let(:current) { nil }

    before do
      allow(subject).to receive(:default).and_return("default")
      allow(::Installation::SystemRole).to receive(:current).and_return(current)
    end

    context "when no system role is selected" do
      it "sets the default value as the current one" do
        expect(subject).to receive(:value=).with("default")
        subject.init
      end
    end

    context "when a system role is selected" do
      let(:current) { "alt_role" }

      it "sets the selected value as the current one" do
        expect(subject).to receive(:value=).with(current)
        subject.init
      end
    end
  end

  describe "#label" do
    it "returns the roles caption" do
      allow(Yast::ProductControl).to receive(:GetTranslatedText).with("roles_caption")
        .and_return("caption")
      expect(subject.label).to eq("caption")
    end
  end

  describe "#items" do
    it "returns roles ids and labels" do
      expect(subject.items).to eq([["default", "Default Role"], ["alt", "Alternate Role"]])
    end
  end

  describe "#help" do
    it "returns role help" do
      expect(subject.help).to include("Default Role\n\nRole description")
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return("alt")
      allow(alt_role).to receive(:overlay_features)
      allow(alt_role).to receive(:adapt_services)
    end

    it "overlays role features" do
      expect(alt_role).to receive(:overlay_features)
      subject.store
    end

    it "adapts services" do
      expect(alt_role).to receive(:adapt_services)
      subject.store
    end
  end
end

#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/widgets/polkit_default_priv"
require "cwm/rspec"

describe Installation::Widgets::PolkitDefaultPriv do
  let(:settings) { Installation::SecuritySettings.create_instance }
  subject { described_class.new(settings) }

  include_examples "CWM::ComboBox"

  describe ".store" do
    let(:selected) { "" }

    before do
      allow(subject).to receive(:value).and_return(selected)
    end

    context "when the value selected is the 'Default'" do
      it "sets the settings polkit_default_privileges to nil" do
        expect(settings).to receive(:polkit_default_privileges=).with(nil)
        subject.store
      end
    end

    context "when the value selected is other" do
      let(:selected) { "restrictive" }

      it "sets the settings with the selected value" do
        expect(settings).to receive(:polkit_default_privileges=).with("restrictive")
        subject.store
      end
    end
  end
end

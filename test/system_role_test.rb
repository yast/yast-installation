#! /usr/bin/env rspec

require_relative "./test_helper"
require "installation/services"
require "installation/system_role"

describe Installation::SystemRole do
  let(:system_roles) do
    [
      {
        "id"       => "role_one",
        "services" => [{ "name" => "service_one" }],
        "software" => { "desktop" => "knome" },
        "order"    => "500"
      },
      {
        "id"       => "role_two",
        "services" => [{ "name" => "service_one" }, { "name" => "service_two" }],
        "order"    => "100"
      }
    ]
  end

  before do
    allow(Yast::ProductControl).to receive(:system_roles).and_return(system_roles)
    described_class.clear
  end

  describe ".raw_roles" do
    it "returns the roles from the control file" do
      raw_roles = described_class.raw_roles

      expect(raw_roles.size).to eql 2
      expect(raw_roles.first["id"]).to eql "role_one"
    end
  end

  describe ".ids" do
    it "returns a list with all the role ids declared in the control file" do
      expect(described_class.ids).to match_array(["role_one", "role_two"])
    end
  end

  describe ".all" do
    it "returns an array of SystemRole objects for all the declared roles " do
      expect(described_class.all.size).to eql(2)
      expect(described_class.all.last.class).to eql(described_class)
    end

    it "returns array sorted by order" do
      expect(described_class.all.first.id).to eql("role_two")
    end
  end

  describe ".default?" do
    it "returns true if default option should be set" do
      expect(described_class.default?).to eq true
    end
  end

  describe ".find" do
    it "looks for the given role 'id' and returns the specific SystemRole object" do
      role_two = described_class.find("role_two")
      expect(role_two.id).to eq("role_two")
    end
  end

  describe ".select" do
    it "selects as the current role the one given by parameter" do
      described_class.select("role_two")
      expect(described_class.current).to eql("role_two")

      described_class.select("role_one")
      expect(described_class.current).to eql("role_one")
    end

    it "returns the SystemRole object selected" do
      selected = described_class.select("role_two")

      expect(selected.class).to eql(described_class)
      expect(selected.id).to eql("role_two")
    end
  end

  describe ".current" do
    it "returns the 'id' of the current selected role" do
      described_class.select("role_two")

      expect(described_class.current).to eql("role_two")
    end
  end

  describe ".from_control" do
    it "creates a new instance of SystemRole based on a control file role entry definition" do
      raw_role = {
        "id"                 => "raw_role",
        "services"           => [{ "name" => "services_one" }],
        "additional_dialogs" => "dialog"
      }

      system_role = described_class.from_control(raw_role)

      expect(system_role.class).to eql(described_class)
      expect(system_role.id).to eql("raw_role")
      expect(system_role["services"]).to eq([{ "name" => "services_one" }])
      expect(system_role["additional_dialogs"]).to eq("dialog")
    end
  end

  describe ".clear" do
    it "clears roles cache" do
      expect(Yast::ProductControl).to receive(:system_roles).twice
      described_class.all
      described_class.clear
      described_class.all
    end
  end

  describe "#adapt_services" do
    it "sets to be enable the specific services for this role" do
      role = described_class.find("role_two")

      expect(Installation::Services).to receive(:enabled=).with(["service_one", "service_two"])

      role.adapt_services
    end
  end

  describe "#overlay_features" do
    it "overlays the product features with the ones defined in the control file for this role" do
      role = described_class.find("role_one")

      expect(Yast::ProductFeatures).to receive(:SetOverlay)
        .with("software" => { "desktop" => "knome" })

      role.overlay_features
    end
  end
end

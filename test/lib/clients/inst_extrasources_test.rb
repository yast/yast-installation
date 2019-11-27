require_relative "../../test_helper"
require "installation/clients/inst_extrasources"

describe Yast::InstExtrasourcesClient do
  subject(:client) { described_class.new }

  describe "#UpgradesAvailable" do
    it "returns available package updates" do
      source = 42
      expect(Yast::Pkg).to receive(:GetPackages).and_return(["foo"])
      expect(Y2Packager::Resolvable).to receive(:find)
        .with(kind: :package, name: "foo", status: :selected)
        .and_return([Y2Packager::Resolvable.new(
          "kind" => :package, "name" => "foo", "version" => "1.0", "arch" => "x86_64",
          "status" => :selected, "source" => source
        )])
      expect(subject.UpgradesAvailable([source])).to eq("packages"     => ["foo-1.0.x86_64"],
                                                        "repositories" => [source])
    end
  end
end

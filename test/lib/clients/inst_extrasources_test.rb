require_relative "../../test_helper"
require "installation/clients/inst_extrasources"

describe Yast::InstExtrasourcesClient do
  subject(:client) { described_class.new }

  describe "#UpgradesAvailable" do
    it "returns available package updates" do
      source = 42
      expect(Yast::Pkg).to receive(:GetPackages).and_return(["foo"])
      expect(Yast::Pkg).to receive(:ResolvableProperties).with("foo", :package, "")
        .and_return(["name" => "foo", "version" => "1.0", "arch" => "x86_64",
          "status" => :selected, "source" => source])
      expect(subject.UpgradesAvailable([source])).to eq("packages"     => ["foo-1.0.x86_64"],
                                                        "repositories" => [source])
    end
  end
end

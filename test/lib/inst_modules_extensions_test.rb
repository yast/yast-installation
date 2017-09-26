#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/clients/inst_modules_extensions"

describe ::Installation::Clients::InstModulesExtensions do
  describe "#run" do
    before do
      allow(Yast::Pkg).to receive(:PkgQueryProvides).and_return([["package_a"], ["package_b"]])

      allow(Yast::Pkg).to receive(:ResolvableDependencies).with("package_a", :package, "")
        .and_return([{ "deps" => [{ "provides" => "installer_module_extension() = module_a" }] }])

      allow(Yast::Pkg).to receive(:ResolvableDependencies).with("package_b", :package, "")
        .and_return([{ "deps" => [{ "provides" => "installer_module_extension() = module_b" }] }])

      allow(Yast::WorkflowManager).to receive(:merge_modules_extensions)
    end

    it "returns :back if going back" do
      allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)

      expect(subject.run).to eq :back
    end

    it "returns :next otherwise" do
      expect(subject.run).to eq :next
    end

    it "merges installation workflow for module extension packages" do
      expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with(["package_a", "package_b"])

      subject.run
    end
  end
end

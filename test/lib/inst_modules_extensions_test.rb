#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/clients/inst_modules_extensions"

describe ::Installation::Clients::InstModulesExtensions do
  describe "#run" do
    let(:deps_package_a) do
      { "deps" => [{ "provides" => "installer_module_extension() = module_a" }] }
    end
    let(:deps_package_b) do
      { "deps" => [{ "provides" => "installer_module_extension() = module_b" }] }
    end
    let(:product) { Y2Packager::Product.new(name: "SLES") }

    before do
      allow(Yast::Pkg).to receive(:PkgQueryProvides).and_return([["package_a"], ["package_b"]])

      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :package, name: "package_a")
        .and_return([Y2Packager::Resolvable.new(deps_package_a)])

      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :package, name: "package_b")
        .and_return([Y2Packager::Resolvable.new(deps_package_b)])

      allow(Yast::WorkflowManager).to receive(:merge_modules_extensions)

      allow(Y2Packager::Product).to receive(:selected_base).and_return(product)
    end

    it "returns :back if going back" do
      allow(Yast::GetInstArgs).to receive(:going_back).and_return(true)

      expect(subject.run).to eq :back
    end

    it "returns :next otherwise" do
      expect(subject.run).to eq :next
    end

    context "when no product is specified in roles" do
      it "merges installation workflow for all module extension packages" do
        expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with(["package_a",
                                                                                  "package_b"])

        subject.run
      end
    end

    context "when all roles are specified for a different product" do
      let(:deps_package_a) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_b" },
                     { "provides" => "extension_for_product() = SLED" }] }
      end
      let(:deps_package_b) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_a" },
                     { "provides" => "extension_for_product() = SLED" }] }
      end

      it "does not merge installation workflow for the module extension packages" do
        expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with([])

        subject.run
      end
    end

    context "when only one role is specified for a different product" do
      let(:deps_package_a) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_b" },
                     { "provides" => "extension_for_product() = SLED" }] }
      end

      it "merges installation workflow for the other module extension packages" do
        expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with(["package_b"])

        subject.run
      end
    end

    context "when all roles are specified only for the current product" do
      let(:deps_package_a) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_b" },
                     { "provides" => "extension_for_product() = SLES" }] }
      end
      let(:deps_package_b) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_a" },
                     { "provides" => "extension_for_product() = SLES" }] }
      end

      it "merges installation workflow for all module extension packages" do
        expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with(["package_a",
                                                                                  "package_b"])

        subject.run
      end
    end

    context "when all roles are specified for multiple products, including the current one" do
      let(:deps_package_a) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_b" },
                     { "provides" => "extension_for_product() = SLES" },
                     { "provides" => "extension_for_product() = SLED" }] }
      end
      let(:deps_package_b) do
        { "deps" => [{ "provides" => "installer_module_extension() = module_a" },
                     { "provides" => "extension_for_product() = SLED" },
                     { "provides" => "extension_for_product() = SLES" }] }
      end

      it "merges installation workflow for all module extension packages" do
        expect(Yast::WorkflowManager).to receive(:merge_modules_extensions).with(["package_a",
                                                                                  "package_b"])

        subject.run
      end
    end
  end
end

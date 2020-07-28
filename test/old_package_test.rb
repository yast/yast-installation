#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/old_package"

data_path = File.join(__dir__, "data", "old_packages")

describe Installation::OldPackage do
  describe ".read" do
    it "reads the data files" do
      pkgs = Installation::OldPackage.read([data_path])
      expect(pkgs.size).to eq(4)
      pkgs.each { |p| expect(p).to be_a(Installation::OldPackage) }
    end
  end

  describe "#selected_old" do
    subject { Installation::OldPackage.read([data_path]).first }

    context "no package is selected" do
      before do
        expect(Yast::Pkg).to receive(:ResolvableProperties).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_old).to be_nil
      end
    end

    context "an old package is selected" do
      let(:old_package) do
        { "name" => "yast2", "version" => "4.1.69-1.2", "arch" => "x86_64", "status" => :selected }
      end

      before do
        expect(Yast::Pkg).to receive(:ResolvableProperties).and_return([old_package])
      end

      it "returns the old package Resolvable" do
        expect(subject.selected_old).to eq(old_package)
      end
    end

    context "a new package is selected" do
      let(:new_package) do
        { "name" => "yast2", "version" => "4.1.99-1.2", "arch" => "x86_64", "status" => :selected }
      end

      before do
        expect(Yast::Pkg).to receive(:ResolvableProperties).and_return([new_package])
      end

      it "returns nil" do
        expect(subject.selected_old).to be_nil
      end
    end
  end
end

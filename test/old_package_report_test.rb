#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/old_package"
require "installation/old_package_report"

describe Installation::OldPackageReport do
  let(:message1) { "These packages are too old, install new ones." }
  let(:message2) { "This package contains a bug." }
  let(:old_package1) do
    Installation::OldPackage.new(
      name:    "yast2",
      version: "4.1.77-1.1",
      arch:    "x86_64",
      message: message1
    )
  end
  let(:old_package2) do
    Installation::OldPackage.new(
      name:    "yast2-pkg-bindings",
      version: "4.1.2-3.5.9",
      arch:    "x86_64",
      message: message2
    )
  end

  subject { Installation::OldPackageReport.new([old_package1, old_package2]) }

  describe "#report" do
    before do
      expect(old_package1).to receive(:selected_old).at_least(:once)
        .and_return(selected_package1)
      expect(old_package2).to receive(:selected_old).at_least(:once)
        .and_return(selected_package2)
    end

    context "No old package selected" do
      let(:selected_package1) { nil }
      let(:selected_package2) { nil }

      it "does not report any error" do
        expect(Yast::Report).to_not receive(:LongWarning)
        subject.report
      end
    end

    context "An old package is selected" do
      let(:selected_package1) do
        Y2Packager::Resolvable.new(
          "name"    => "yast2",
          "version" => "4.1.77-1.1",
          "arch"    => "x86_64"
        )
      end
      let(:selected_package2) { nil }

      it "reports an error" do
        expect(Yast::Report).to receive(:LongWarning).with(/#{message1}/)
        subject.report
      end
    end

    context "More old packages are selected" do
      let(:selected_package1) do
        Y2Packager::Resolvable.new(
          "name"    => "yast2",
          "version" => "4.1.77-1.1",
          "arch"    => "x86_64"
        )
      end
      let(:selected_package2) do
        Y2Packager::Resolvable.new(
          "name"    => "yast2-pkg-bindings",
          "version" => "4.1.2-3.5.9",
          "arch"    => "x86_64"
        )
      end

      it "reports an error for all packages" do
        expect(Yast::Report).to receive(:LongWarning) do |message|
          expect(message).to include(message1)
          expect(message).to include(message2)
        end

        subject.report
      end

      it "groups the packages with the same message" do
        allow(old_package2).to receive(:message).and_return(message1)

        expect(Yast::Report).to receive(:LongWarning) do |message|
          expect(message.scan(message1).size).to eq(1)
        end

        subject.report
      end
    end
  end
end

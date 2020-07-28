#! /usr/bin/env rspec

require_relative "./test_helper"

Yast.import "ImageInstallation"
Yast.import "Installation"

# For mocking
Yast.import "Pkg"
Yast.import "Arch"

IMAGES_DESCR_FILE = File.join(File.expand_path(File.dirname(__FILE__)), "data/images/images.xml")

KDE4_PATTERNS  = ["base", "enhanced_base", "games", "imaging", "kde4", "kde4_basis", "multimedia", "sw_management", "x11"].freeze
GNOME_PATTERNS = ["base", "enhanced_base", "fonts", "games", "gnome", "gnome_basis", "imaging", "multimedia", "sw_management", "x11"].freeze
X11_PATTERNS   = ["base", "enhanced_base", "fonts", "sw_management", "x11"].freeze
BASE_PATTERNS  = ["base", "enhanced_base", "sw_management"].freeze

NON_MATCHING_PATTERNS_1 = ["games", "gnome_basis"].freeze
NON_MATCHING_PATTERNS_2 = ["enhanced_base"].freeze

NON_MATCHING_ARCH = "unsupported".freeze

ARCHS = ["i386", "x86_64", "ppc"].freeze

describe Yast::ImageInstallation do
  subject { described_class }

  before do
    stub_const("Yast::Packages", double(theSources: [0]))
  end

  describe "#FindImageSet" do
    before(:each) do
      allow(Yast::Pkg).to receive(:SourceProvideDigestedFile).and_return(IMAGES_DESCR_FILE)
    end

    it "finds images matching architecture and selected patterns and returns if processing was successful" do
      ARCHS.each do |arch|
        allow(Yast::Arch).to receive(:arch_short).and_return(arch)

        [KDE4_PATTERNS, GNOME_PATTERNS, X11_PATTERNS, BASE_PATTERNS].each do |patterns|
          Yast::ImageInstallation.FreeInternalVariables()
          expect(Yast::ImageInstallation.FindImageSet(patterns)).to eq(true)
          expect(Yast::Installation.image_installation).to eq(true)
          expect(Yast::ImageInstallation.selected_images["archs"]).to eq(arch)
        end
      end
    end

    it "does not find any image using unsupported architecture and returns if processing was successful" do
      [KDE4_PATTERNS, GNOME_PATTERNS, X11_PATTERNS, BASE_PATTERNS].each do |patterns|
        allow(Yast::Arch).to receive(:arch_short).and_return(NON_MATCHING_ARCH)
        Yast::ImageInstallation.FreeInternalVariables()

        expect(Yast::ImageInstallation.FindImageSet(patterns)).to eq(true)
        expect(Yast::Installation.image_installation).to eq(false)
        expect(Yast::ImageInstallation.selected_images).to be_empty
      end
    end

    it "does not find any image using unsupported patterns and returns if processing was successful" do
      ARCHS.each do |arch|
        allow(Yast::Arch).to receive(:arch_short).and_return(arch)

        [NON_MATCHING_PATTERNS_2, NON_MATCHING_PATTERNS_2].each do |patterns|
          Yast::ImageInstallation.FreeInternalVariables()

          expect(Yast::ImageInstallation.FindImageSet(patterns)).to eq(true)
          expect(Yast::Installation.image_installation).to eq(false)
          expect(Yast::ImageInstallation.selected_images).to be_empty
        end
      end
    end

    it "returns true if no xml is provided" do
      allow(Yast::Pkg).to receive(:SourceProvideDigestedFile).and_return(nil)

      expect(subject.FindImageSet([])).to eq true
    end

    it "returns false if xml is not valid" do
      allow(Yast::XML).to receive(:XMLToYCPFile).and_raise(Yast::XMLDeserializationError)

      expect(subject.FindImageSet([])).to eq false
    end
  end
end

#! /usr/bin/env rspec

require_relative "./test_helper"

Yast.import "InstFunctions"

# For mocking
Yast.import "Linuxrc"

def stub_install_inf(install_inf)
  allow(Yast::Linuxrc).to receive(:keys).and_return(install_inf.keys)

  install_inf.keys.each do |key|
    allow(Yast::Linuxrc).to receive(:InstallInf).with(key).and_return(install_inf[key])
  end
end

describe "when getting list of ignored features from Linuxrc" do
  before(:each) do
    Yast::InstFunctions.reset_ignored_features
  end

  it "returns empty list if no features were ignored on commandline" do
    linuxrc_commandline = "othercommand=xyz no_ignore_features=1 something-else=555"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to be_empty
  end

  it "returns empty list if features ignored on commandline were empty" do
    linuxrc_commandline = "ignore_features="

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to be_empty
  end

  it "returns list of features set on commandline by two entries" do
    linuxrc_commandline = "ignore_features=aa,b_b,c-c ignoredfeatures=a-a,dd othercommand=xyz"
    ignored_features    = ["aa", "bb", "cc", "dd"].sort

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by one entry" do
    linuxrc_commandline = "ignore_features=x-x,yy"
    ignored_features    = ["xx", "yy"].sort

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by several entries, each feature in separate entry" do
    linuxrc_commandline = "trash=install ignore_feature=f.e.a.ture1 ig.n.o.red_features=feature2 ignore_features=feature3"
    ignored_features    = ["feature1", "feature2", "feature3"].sort

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns one feature set on commandline by one entry" do
    linuxrc_commandline = "i-g-n-o-r-e_feature=fff"
    ignored_features    = ["fff"]

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns one feature set on commandline by one entry using up/down case" do
    linuxrc_commandline = "Ignore_FeaTUres=ffF"
    ignored_features    = ["fff"]

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  # PTOptions makes a command hidden from 'Cmdline' and creates
  # a new install.inf entry using the exact name as it appears in PTOptions
  # @see http://en.opensuse.org/SDB:Linuxrc#p_ptoptions
  it "returns features set on commandline together with ptoptions" do
    install_inf = {
      "ignored_features"       => "f1,f2,f3",
      "IgnoReDfEAtuRes"        => "f2,f4",
      "i.g.n.o.r.e.d.features" => "f1,f5",
      "IGNORE-FEA-T-U-RE"      => "f6,f7,f7,f7",
      "another_feature"        => "another_value",
      "Cmdline"                => "splash=silent vga=0x314",
      "Keyboard"               => "1"
    }
    stub_install_inf(install_inf)

    expect(Yast::InstFunctions.ignored_features.sort).to eq(["f1", "f2", "f3", "f4", "f5", "f6", "f7"])
  end

  it "handles missing Cmdline in Linuxrc" do
    install_inf = {
      # Cmdline is not defined, bnc#861465
      "Cmdline" => nil
    }
    stub_install_inf(install_inf)

    expect(Yast::InstFunctions.ignored_features.sort).to be_empty
  end
end

describe "#feature_ignored?" do
  before(:each) do
    Yast::InstFunctions.reset_ignored_features
  end

  it "should be true if feature is exactly set on commandline" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("feature2")).to eq(true)
  end

  it "should be true if feature is exactly on commandline using up/down case" do
    linuxrc_commandline = "trash=install ignore_features=fEAture1 igno-RED_features=f-eatuRE_2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("f-e-a-t-u-r-e-2")).to eq(true)
  end

  it "should be true if feature is set on commandline with dashes and underscores" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("f-e-a-t-u-r-e_2")).to eq(true)
  end

  it "should be false if feature is not set on commandline" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("no-such-feature")).to eq(false)
  end

  it "should be false if feature to check is empty" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("")).to eq(false)
  end

  it "should be false if feature to check is undefined" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?(nil)).to eq(false)
  end

  it "should be true if feature is mentioned as a separate install.inf entry or in Cmdline" do
    install_inf = {
      "ignored_features"       => "f1,f2,f3",
      "IgnoReDfEAtuRes"        => "f2,f4",
      "i.g.n.o.r.e.d.features" => "f1,f5",
      "IGNORED-FEA-T-U-RES"    => "f6,f7,f7,f7",
      "another_feature"        => "another_value",
      "Cmdline"                => "splash=silent vga=0x314 ignored_feature=f8",
      "Keyboard"               => "1"
    }
    stub_install_inf(install_inf)

    ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8"].each do |key|
      expect(Yast::InstFunctions.feature_ignored?(key)).to eq(true), "Key #{key} is not ignored"
    end
  end

  it "should be false if feature is not mentioned as a separate install.inf entry or in Cmdline" do
    install_inf = {
      "ignored_features"       => "f1,f2,f3",
      "IgnoReDfEAtuRes"        => "f2,f4",
      "i.g.n.o.r.e.d.features" => "f1,f5",
      "IGNORE-FEA-T-U-RE"      => "f6,f7,f7,f7",
      "another_feature"        => "another_value",
      "Cmdline"                => "splash=silent vga=0x314 ignored_feature=f8",
      "Keyboard"               => "1"
    }
    stub_install_inf(install_inf)

    expect(Yast::InstFunctions.feature_ignored?("f9")).to eq(false)
  end
end

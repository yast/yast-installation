#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "InstFunctions"

# For mocking
Yast.import "Linuxrc"

describe "when getting list of ignored features from Linuxrc" do
  before(:each) do
    Yast::InstFunctions.reset_ignored_features
  end

  it "returns empty list if no features were ignored on commandline" do
    linuxrc_commandline = "othercommand=xyz no_ignore_features=1 something-else=555"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to be_empty
  end

  it "returns empty list if features ignored on commandline were empty" do
    linuxrc_commandline = "ignore_features="

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to be_empty
  end

  it "returns list of features set on commandline by two entries" do
    linuxrc_commandline = "ignore_features=aa,b_b,c-c ignoredfeatures=a-a,dd othercommand=xyz"
    ignored_features    = ["aa", "bb", "cc", "dd"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by one entry" do
    linuxrc_commandline = "ignore_features=x-x,yy"
    ignored_features    = ["xx", "yy"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by several entries, each feature in separate entry" do
    linuxrc_commandline = "trash=install ignore_feature=feature1 ignored_features=feature2 ignore_features=feature3"
    ignored_features    = ["feature1", "feature2", "feature3"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns one feature set on commandline by one entry" do
    linuxrc_commandline = "i-g-n-o-r-e_feature=fff"
    ignored_features    = ["fff"]

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end

  it "returns one feature set on commandline by one entry using up/down case" do
    linuxrc_commandline = "Ignore_FeaTUres=ffF"
    ignored_features    = ["fff"]

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.ignored_features.sort).to eq ignored_features
  end
end

describe "when checking whether feature is ignored" do
  before(:each) do
    Yast::InstFunctions.reset_ignored_features
  end

  it "should be true if feature is exactly set on commandline" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("feature2")).to be_true
  end

  it "should be true if feature is exactly on commandline using up/down case" do
    linuxrc_commandline = "trash=install ignore_features=fEAture1 igno-RED_features=f-eatuRE_2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("f-e-a-t-u-r-e-2")).to be_true
  end

  it "should be true if feature is set on commandline with dashes and underscores" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("f-e-a-t-u-r-e_2")).to be_true
  end

  it "should be false if feature is not set on commandline" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("no-such-feature")).to be_false
  end

  it "should be false if feature to check is empty" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?("")).to be_false
  end

  it "should be false if feature to check is undefined" do
    linuxrc_commandline = "trash=install ignore_features=feature1 ignored_features=feature2 ignore_features=feature3"

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.feature_ignored?(nil)).to be_false
  end
end

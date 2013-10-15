#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "InstFunctions"

# For mocking
Yast.import "Linuxrc"

describe "when getting list of ignored features from Linuxrc" do
  it "returns empty list if no features were ignored on commandline" do
    linuxrc_commandline = "othercommand=xyz no_ignored_features=1 something-else=555"
    ignored_features    = []

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end

  it "returns empty list if features ignored on commandline were empty" do
    linuxrc_commandline = "ignored_features="
    ignored_features    = []

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by two entries" do
    linuxrc_commandline = "ignored_features=aa,b_b,c-c ignoredfeature=a-a,dd othercommand=xyz"
    ignored_features    = ["aa", "bb", "cc", "dd"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by one entry" do
    linuxrc_commandline = "ignore_feature=x-x,yy"
    ignored_features    = ["xx", "yy"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end

  it "returns list of features set on commandline by several entries, each feature in separate entry" do
    linuxrc_commandline = "trash=install ignore_feature=feature1 ignore_feature=feature2 ignore_feature=feature3"
    ignored_features    = ["feature1", "feature2", "feature3"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end

  it "returns one feature set on commandline by one entry" do
    linuxrc_commandline = "ignore_feature=fff"
    ignored_features    = ["fff"].sort

    Yast::Linuxrc.stub(:InstallInf).and_return(linuxrc_commandline)
    expect(Yast::InstFunctions.IgnoredFeatures.sort).to eq ignored_features
  end
end

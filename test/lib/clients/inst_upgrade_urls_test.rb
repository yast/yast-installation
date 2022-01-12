#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/inst_upgrade_urls"

describe Yast::InstUpgradeUrlsClient do
  let(:repo1) do
    Y2Packager::Repository.new(repo_id: 1, repo_alias: "test1",
      url: "https://example.com/1", raw_url: "https://example.com/1",
      name: "repo1", enabled: true, autorefresh: true)
  end

  let(:repo2) do
    Y2Packager::Repository.new(repo_id: 2, repo_alias: "test2",
      url: "https://example.com/2", raw_url: "https://example.com/2",
      name: "repo2", enabled: true, autorefresh: true)
  end

  let(:service1) do
    Y2Packager::Service.new(service_alias: "service1", name: "service1",
      url: "https://example.com/service", enabled: true, auto_refresh: true)
  end

  let(:repo_mgr) { Installation::UpgradeRepoManager.new([repo1, repo2], [service1]) }

  before do
    allow(Yast::GetInstArgs).to receive(:going_back).and_return(false)
    allow(Yast::Stage).to receive(:initial).and_return(true)
    allow(Yast::Mode).to receive(:update).and_return(true)
    allow(Yast::Mode).to receive(:normal).and_return(false)
    allow(Yast::Wizard).to receive(:SetContents)

    allow(Installation::UpgradeRepoManager).to receive(:create_from_old_repositories)
      .and_return(repo_mgr)

    allow(Yast::UI).to receive(:QueryWidget)
    allow(Yast::UI).to receive(:ChangeWidget)
    allow(Yast::Pkg).to receive(:SourceSaveAll)
  end

  describe "#main" do
    before do
      allow(repo1).to receive(:delete!)
      allow(repo2).to receive(:delete!)
      allow(Yast::Pkg).to receive(:ServiceDelete).with(service1.alias)
    end

    it "removes the selected repositories after pressing Next" do
      expect(Yast::UI).to receive(:UserInput).and_return(:next)
      expect(repo1).to receive(:delete!)
      expect(repo2).to receive(:delete!)
      subject.main
    end

    it "removes all old services after pressing Next" do
      expect(Yast::UI).to receive(:UserInput).and_return(:next)
      expect(Yast::Pkg).to receive(:ServiceDelete).with(service1.alias)
      subject.main
    end
  end
end

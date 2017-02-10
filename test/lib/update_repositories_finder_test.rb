#!/usr/bin/env rspec

require_relative "../test_helper"
require "installation/update_repositories_finder"

Yast.import "Linuxrc"

describe Installation::UpdateRepositoriesFinder do
  describe "#updates" do
    let(:url_from_linuxrc) { nil }
    let(:url_from_control) { "http://update.opensuse.org/\$arch/42.2" }
    let(:real_url_from_control) { "http://update.opensuse.org/#{arch}/42.2" }
    let(:arch) { "x86_64" }
    let(:profile) { {} }
    let(:ay_profile) { double("Yast::Profile", current: profile) }
    let(:repo) { double("UpdateRepository") }

    subject(:finder) { described_class.new }

    before do
      stub_const("Yast::Profile", ay_profile)
      allow(Installation::UpdateRepository).to receive(:new)
        .and_return(repo)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("SelfUpdate")
        .and_return(url_from_linuxrc)
    end

    context "when URL was specified via Linuxrc" do
      let(:url_from_linuxrc) { "http://example.net/sles12/" }

      it "returns the custom URL from Linuxrc" do
        expect(Installation::UpdateRepository).to receive(:new)
          .with(URI(url_from_linuxrc), :user)
        update = finder.updates.first
        expect(update).to eq(repo)
      end
    end

    context "when URL was specified via an AutoYaST profile" do
      let(:profile_url) { "http://ay.test.example.com/update" }
      let(:profile) { { "general" => { "self_update_url" => profile_url } } }

      before do
        allow(Yast::Mode).to receive(:auto).and_return(true)
      end

      it "returns the custom URL from the profile" do
        expect(Installation::UpdateRepository).to receive(:new)
          .with(URI(profile_url), :user)
        update = finder.updates.first
        expect(update).to eq(repo)
      end
    end

    context "when no custom URL is specified" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature)
          .with("globals", "self_update_url")
          .and_return(url_from_control)
        # TODO: test don't mock!
        allow(finder).to receive(:add_installation_repo)
        allow(Yast::Linuxrc).to receive(:InstallInf).with("regurl")
          .and_return(nil)
      end

      it "returns the URL from the control file" do
        expect(Installation::UpdateRepository).to receive(:new)
          .with(URI(real_url_from_control), :default)
        update = finder.updates.first
        expect(update).to eq(repo)
      end
    end
  end
end

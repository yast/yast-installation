#! /usr/bin/env rspec

# Copyright (c) [2015-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "./test_helper"
require_relative "../src/include/installation/misc"

Yast.import "UI"
Yast.import "Mode"

# A dummy class for testing the "misc" include
class InstallationMiscIncludeTest < Yast::Client
  include Yast::I18n

  def initialize
    Yast.include self, "installation/misc.rb"
  end
end

describe Yast::InstallationMiscInclude do
  subject { InstallationMiscIncludeTest.new }

  RSpec.shared_examples "confirmation dialog" do
    it "displays proper heading, text, and confirmation label" do
      expect(Yast::UI).to receive(:OpenDialog) do |term|
        content = term.nested_find { |e| e.is_a?(Yast::Term) && e.value == :RichText }

        confirm_button = term.nested_find do |e|
          e.is_a?(Yast::Term) && e.value == :PushButton && e.params.include?(confirm_label)
        end

        expect(content.params).to include(/#{heading}/)
        expect(content.params).to include(/#{body_fragment}/)
        expect(confirm_button).to_not be_nil
      end

      subject.confirmInstallation
    end
  end

  describe "#confirmInstallation" do
    before do
      allow(Yast::Mode).to receive(:update).and_return(update_mode)
    end

    context "when performing an installation" do
      let(:update_mode) { false }
      let(:heading) { "<h3>Confirm Installation</h3>" }
      let(:body_fragment) { "partitions on your\nhard disk will be modified" }
      let(:confirm_label) { "&Install" }

      include_examples "confirmation dialog"
    end

    context "when performing an update" do
      let(:update_mode) { true }
      let(:heading) { "<h3>Confirm Update</h3>" }
      let(:body_fragment) { "data on your hard disk will be overwritten" }
      let(:confirm_label) { "Start &Update" }

      include_examples "confirmation dialog"
    end
  end
end

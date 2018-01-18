#!/usr/bin/env rspec
# Copyright (c) [2017] SUSE LLC
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

require_relative "../../test_helper"
require "installation/clients/inst_system_analysis"

describe Yast::InstSystemAnalysisClient do
  subject(:client) { described_class.new }

  describe "#ActionHDDProbe" do
    let(:storage) do
      instance_double(Y2Storage::StorageManager, activate: true, probe: nil, probed: devicegraph)
    end

    let(:devicegraph) { instance_double(Y2Storage::Devicegraph, empty?: false) }
    let(:auto) { false }

    before do
      allow(client).to receive(:require).with("autoinstall/activate_callbacks")
    end

    before do
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage)
      allow(Yast::Mode).to receive(:auto).and_return(auto)
    end

    it "uses default activation callbacks" do
      expect(storage).to receive(:activate).with(nil)
      client.ActionHDDProbe
    end

    context "when running AutoYaST" do
      let(:auto) { true }
      let(:callbacks_class) { double("Y2Autoinstallation::ActivateCallbacks", new: callbacks) }
      let(:callbacks) { instance_double("Y2Autoinstallation::ActivateCallbacks") }

      before { stub_const("Y2Autoinstallation::ActivateCallbacks", callbacks_class) }

      it "uses AutoYaST activation callbacks" do
        expect(storage).to receive(:activate).with(callbacks)
        client.ActionHDDProbe
      end
    end
  end
end

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

    let(:devicegraph) { instance_double(Y2Storage::Devicegraph, empty?: empty) }
    let(:auto) { false }
    let(:activate_result) { true }
    let(:probe_result) { true }
    let(:empty) { false }
    let(:callbacks_class) { double("Y2Autoinstallation::ActivateCallbacks", new: callbacks) }
    let(:callbacks) { instance_double("Y2Autoinstallation::ActivateCallbacks") }

    before do
      allow(client).to receive(:require).with("autoinstall/activate_callbacks")
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage)
      allow(storage).to receive(:activate).and_return activate_result
      allow(storage).to receive(:probe).and_return probe_result
      allow(Yast::Mode).to receive(:auto).and_return(auto)
      allow(Yast::Execute).to receive(:locally!)
      stub_const("Y2Autoinstallation::ActivateCallbacks", callbacks_class)
    end

    it "uses default activation callbacks" do
      expect(storage).to receive(:activate).with(nil).and_return true
      expect(Yast::Execute).to receive(:locally!)
        .with("/sbin/udevadm", "control", "--property=ANACONDA=yes").ordered
      expect(Yast::Execute).to receive(:locally!)
        .with("/usr/lib/YaST2/bin/mask-systemd-units", "--mask").ordered
      client.ActionHDDProbe
    end

    context "when running AutoYaST" do
      let(:auto) { true }

      it "uses AutoYaST activation callbacks" do
        expect(storage).to receive(:activate).with(callbacks).and_return true
        client.ActionHDDProbe
      end
    end

    context "when activation fails and the error is not recovered" do
      let(:activate_result) { false }

      it "does not probe and raises AbortException" do
        expect(storage).to_not receive(:probe)
        expect { client.ActionHDDProbe }.to raise_error Yast::AbortException
      end
    end

    context "when probing fails and the error is not recovered" do
      let(:probe_result) { false }

      it "raises AbortException" do
        expect { client.ActionHDDProbe }.to raise_error Yast::AbortException
      end
    end

    context "when no devices are detected" do
      let(:empty) { true }

      context "and not running AutoYaST" do
        let(:auto) { false }

        it "displays an error" do
          expect(Yast::Report).to receive(:Error)
          client.ActionHDDProbe
        end
      end

      context "and running AutoYaST" do
        let(:auto) { true }

        it "does not display any error" do
          expect(Yast::Report).to_not receive(:Error)
          client.ActionHDDProbe
        end
      end
    end
  end
end

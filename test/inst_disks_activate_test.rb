#!/usr/bin/env rspec

require_relative "test_helper"

require "installation/clients/inst_disks_activate"

describe Yast::InstDisksActivateClient do
  describe "#main" do
    let(:s390) { false }
    let(:dasd_disks) { [] }
    let(:zfcp_disks) { [] }

    before do
      Y2Storage::StorageManager.create_test_instance

      allow(Yast::UI).to receive(:OpenDialog)
      allow(Yast::UI).to receive(:CloseDialog)
      allow(Yast::Popup).to receive(:ConfirmAbort).with(:painless).and_return(true)
      allow(Yast::Arch).to receive(:s390).and_return(s390)
      allow(Yast::GetInstArgs).to receive(:going_back) { going_back }
      allow(Yast::Linuxrc).to receive(:InstallInf).with("WithFCoE").and_return("0")
      allow(Yast::UI).to receive(:UserInput).and_return(:abort)

      allow(Y2Storage::StorageManager.instance).to receive(:activate)
      allow(Y2Storage::StorageManager.instance).to receive(:probe)

      allow(Yast::SCR).to receive(:Read).with(path(".probe.disk"))
        .and_return(dasd_disks)
      allow(Yast::SCR).to receive(:Read).with(path(".probe.storage"))
        .and_return(zfcp_disks)

      allow(subject).to receive(:Id)
      allow(subject).to receive(:PushButton)

      stub_const("Yast::Packages", double(GetBaseSourceID: 0))
    end

    it "includes help for Network configuration button" do
      expect(Yast::Wizard).to receive(:SetContents)
        .with(anything, anything, /Network configuration/, any_args)

      subject.main
    end

    it "includes help for iSCSI disks button" do
      expect(Yast::Wizard).to receive(:SetContents)
        .with(anything, anything, /Configure iSCSI Disks/, any_args)

      subject.main
    end

    context "when architecture is s390" do
      let(:s390) { true }

      context "and DASD disks are detected" do
        let(:dasd_disks) { [{ "device" => "DASD" }] }

        before do
          allow(subject).to receive(:Id).with(:dasd).and_return("dasd_button_id")
        end

        it "includes button to configure them" do
          expect(subject).to receive(:PushButton).with("dasd_button_id", any_args)

          subject.main
        end

        it "includes help for DASD button" do
          expect(Yast::Wizard).to receive(:SetContents)
            .with(anything, anything, /Configure DASD/, any_args)

          subject.main
        end

        context "and DASD button is clicked" do
          before do
            allow(Yast::UI).to receive(:UserInput).and_return(:dasd, :abort)
          end

          it "calls inst_dasd client" do
            expect(Yast::WFM).to receive(:call).with("inst_dasd")
            expect(subject).to receive(:show_base_dialog).twice

            subject.main
          end
        end
      end

      context "and zFCP disks are detected" do
        let(:zfcp_disks) { [{ "device" => "zFCP controller" }] }

        before do
          allow(subject).to receive(:Id).with(:zfcp).and_return("zfcp_button_id")
        end

        it "includes button to configure them" do
          expect(subject).to receive(:PushButton).with("zfcp_button_id", any_args)

          subject.main
        end

        it "includes help for zFCP button" do
          expect(Yast::Wizard).to receive(:SetContents)
            .with(anything, anything, /Configure zFCP/, any_args)

          subject.main
        end

        context "and zFCP button is clicked" do
          before do
            allow(Yast::UI).to receive(:UserInput).and_return(:zfcp, :abort)
          end

          it "calls inst_dasd client" do
            expect(Yast::WFM).to receive(:call).with("inst_zfcp")
            expect(subject).to receive(:show_base_dialog).twice

            subject.main
          end
        end
      end

      context "and FCoE is available" do
        before do
          allow(Yast::Linuxrc).to receive(:InstallInf).with("WithFCoE").and_return("1")

          allow(subject).to receive(:Id).with(:fcoe).and_return("fcoe_button_id")
        end

        it "includes button to configure it" do
          expect(subject).to receive(:PushButton).with("fcoe_button_id", any_args)

          subject.main
        end

        it "includes help for FCoE button" do
          expect(Yast::Wizard).to receive(:SetContents)
            .with(anything, anything, /Configure FCoE/, any_args)

          subject.main
        end
      end
    end

    context "when network button is clicked" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:network, :abort)
      end

      it "calls inst_lan client" do
        expect(Yast::WFM).to receive(:call).with("inst_lan", ["skip_detection" => true])
        expect(subject).to receive(:show_base_dialog).twice

        subject.main
      end
    end

    context "when abort button is clicked" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:abort)
      end

      it "returns :abort" do
        expect(subject).to receive(:show_base_dialog).once

        expect(subject.main).to eq(:abort)
      end
    end
  end
end

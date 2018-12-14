#! /usr/bin/env rspec

require_relative "./test_helper"

require "installation/cio_ignore"

describe ::Installation::CIOIgnore do
  describe "enable/disable" do
    it "take AutoYaST cio_ignore setting" do
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
      allow(Yast::AutoinstConfig).to receive(:cio_ignore).and_return(false)
      ::Installation::CIOIgnore.instance.reset
      expect(::Installation::CIOIgnore.instance.enabled).to eq(false)
    end

    it "take default cio_ignore entry if it is in the normal workflow" do
      allow(Yast::Mode).to receive(:autoinst).and_return(false)
      expect(Yast::AutoinstConfig).not_to receive(:cio_ignore)
      expect(File).to receive(:exist?).with("/proc/sysinfo").exactly(2).times.and_return(false)
      ::Installation::CIOIgnore.instance.reset
      expect(::Installation::CIOIgnore.instance.enabled).to eq(true)
    end
  end
end

describe ::Installation::CIOIgnoreProposal do
  subject { ::Installation::CIOIgnoreProposal.new }

  before(:each) do
    ::Installation::CIOIgnore.instance.reset
  end

  describe "#run" do
    describe "first parameter \"MakeProposal\"" do
      it "returns proposal entry hash containing \"links\", \"help\" and \"preformatted_proposal\"" do
        result = subject.run("MakeProposal")

        expect(result).to have_key("links")
        expect(result).to have_key("help")
        expect(result).to have_key("preformatted_proposal")
      end

      it "change its content based on cio ignore proposal value" do
        ::Installation::CIOIgnore.instance.enabled = false

        result = subject.run("MakeProposal")

        expect(result).to have_key("links")
        expect(result).to have_key("help")
        expect(result["preformatted_proposal"]).to include("disabled")
      end
    end

    describe "first parameter \"Description\"" do
      it "returns proposal metadata hash containing \"rich_text_title\", \"id\" and \"menu_title\"" do
        result = subject.run("Description")

        expect(result).to have_key("rich_text_title")
        expect(result).to have_key("menu_title")
        expect(result).to have_key("id")
      end
    end

    describe "first parameter \"AskUser\"" do
      it "changes proposal if passed with chosen_id in second param hash" do
        params = [
          "AskUser",
          "chosen_id" => ::Installation::CIOIgnoreProposal::CIO_DISABLE_LINK
        ]
        result = subject.run(*params)

        expect(result["workflow_sequence"]).to eq :next
        expect(::Installation::CIOIgnore.instance.enabled).to be false
      end

      it "raises RuntimeError if passed without chosen_id in second param hash" do
        expect { subject.run("AskUser") }.to(
          raise_error(RuntimeError)
        )
      end

      it "raises RuntimeError if \"AskUser\" passed with non-existing chosen_id in second param hash" do
        params = [
          "AskUser",
          "chosen_id" => "non_existing"
        ]

        expect { subject.run(*params) }.to raise_error(RuntimeError)
      end
    end

    it "raises RuntimeError if unknown action passed as first parameter" do
      expect { subject.run("non_existing_action") }.to(
        raise_error(RuntimeError)
      )
    end
  end
end

describe ::Installation::CIOIgnoreFinish do
  subject { ::Installation::CIOIgnoreFinish.new }

  describe "#run" do
    describe "first paramater \"Info\"" do
      it "returns info entry hash with empty \"when\" key for non s390x architectures" do
        arch_mock = double("Yast::Arch", s390: false)
        stub_const("Yast::Arch", arch_mock)

        result = subject.run("Info")

        expect(result["when"]).to be_empty
      end

      it "returns info entry hash with scenarios in \"when\" key for s390x architectures" do
        arch_mock = double("Yast::Arch", s390: true)
        stub_const("Yast::Arch", arch_mock)

        result = subject.run("Info")

        expect(result["when"]).to_not be_empty
      end
    end

    describe "first parameter \"Write\"" do
      before(:each) do
        stub_const("Yast::Installation", double(destdir: "/mnt"))
        stub_const("Yast::Bootloader", double)

        allow(Yast::Bootloader).to receive(:Write) { true }
        allow(Yast::Bootloader).to receive(:Read) { true }
        allow(Yast::Bootloader).to receive(:modify_kernel_params) { true }

        allow(Yast::SCR).to receive(:Execute)
          .and_return("exit" => 0, "stdout" => "", "stderr" => "")

        allow(File).to receive(:write)
      end

      describe "Device blacklisting is disabled" do
        it "does nothing" do
          ::Installation::CIOIgnore.instance.enabled = false

          expect(Yast::SCR).to_not receive(:Execute)
          expect(Yast::Bootloader).to_not receive(:Read)

          subject.run("Write")
        end
      end

      describe "Device blacklisting is enabled" do
        it "calls `cio_ignore --unused --purge`" do
          ::Installation::CIOIgnore.instance.enabled = true

          expect(Yast::SCR).to receive(:Execute)
            .with(
              ::Installation::CIOIgnoreFinish::YAST_BASH_PATH,
              "/sbin/cio_ignore --unused --purge"
            )
            .once
            .and_return("exit" => 0, "stdout" => "", "stderr" => "")

          subject.run("Write")
        end

        it "raises RuntimeError if cio_ignore call failed" do
          ::Installation::CIOIgnore.instance.enabled = true
          stderr = "HORRIBLE ERROR!!!"

          expect(Yast::SCR).to receive(:Execute)
            .with(
              ::Installation::CIOIgnoreFinish::YAST_BASH_PATH,
              "/sbin/cio_ignore --unused --purge"
            )
            .once
            .and_return("exit" => 1, "stdout" => "", "stderr" => stderr)

          expect { subject.run("Write") }.to raise_error(RuntimeError, /stderr/)
        end

        it "adds kernel parameters IPLDEV and CONDEV to the bootloader" do
          expect(Yast::Bootloader).to receive(:modify_kernel_params).once
            .and_return(true)

          subject.run("Write")
        end

        it "writes list of active devices to zipl so it is not blocked" do
          test_output = <<-EOL
Devices that are not ignored:
=============================
0.0.0160
0.0.01c0
0.0.0700-0.0.0702
0.0.fc00
          EOL
          expect(Yast::SCR).to receive(:Execute)
            .with(
              ::Installation::CIOIgnoreFinish::YAST_BASH_PATH,
              "/sbin/cio_ignore -L"
            )
            .once
            .and_return("exit" => 0, "stdout" => test_output, "stderr" => "")

          expect(File).to receive(:write).once do |file, content|
            expect(file).to eq("/mnt/boot/zipl/active_devices.txt")
            expect(content).to match(/0.0.0700-0.0.0702/)
            expect(content).to end_with("\n")
          end

          subject.run("Write")
        end

        it "raises an exception if cio_ignore -L failed" do
          expect(Yast::SCR).to receive(:Execute)
            .with(
              ::Installation::CIOIgnoreFinish::YAST_BASH_PATH,
              "/sbin/cio_ignore -L"
            )
            .once
            .and_return("exit" => 1, "stdout" => "", "stderr" => "FAIL")

          expect { subject.run("Write") }.to raise_error(RuntimeError, /cio_ignore -L failed/)
        end
      end
    end

    it "raises RuntimeError if unknown action passed as first parameter" do
      expect { subject.run("non_existing_action") }.to(
        raise_error(RuntimeError)
      )
    end
  end
end

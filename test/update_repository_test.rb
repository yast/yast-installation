#!/usr/bin/env rspec

require_relative "test_helper"

require "installation/update_repository"
require "uri"
require "pathname"

describe Installation::UpdateRepository do
  TEMP_DIR = Pathname.new(__FILE__).dirname.join("tmp")

  Yast.import "Pkg"

  subject(:repo) { Installation::UpdateRepository.new(uri) }

  let(:uri) { URI("http://updates.opensuse.org/sles12") }
  let(:repo_id) { 1 }
  let(:download_path) { TEMP_DIR.join("download") }
  let(:updates_path) { TEMP_DIR.join("mounts") }
  let(:tmpdir) { TEMP_DIR.join("tmp") }
  let(:probed) { "RPMMD" }
  let(:packages) { [] }

  before do
    allow(Yast::Pkg).to receive(:RepositoryProbe).with(uri.to_s, "/").and_return(probed)
    allow(Yast::Pkg).to receive(:RepositoryAdd)
      .with(hash_including("base_urls" => [uri.to_s]))
      .and_return(repo_id)
    allow(Yast::Pkg).to receive(:SourceRefreshNow).with(repo_id).and_return(true)
    allow(Yast::Pkg).to receive(:SourceLoad).and_return(true)
  end

  describe "#packages" do
    let(:package) do
      { "name" => "pkg1", "path" => "./x86_64/pkg1-3.1.x86_64.rpm", "source" => repo_id }
    end

    let(:from_other_repo) do
      { "name" => "pkg2", "path" => "./x86_64/pkg2-3.1.x86_64.rpm", "source" => repo_id + 1 }
    end

    before do
      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :package, "")
        .and_return(packages)
    end

    context "when the repository type can't be determined" do
      let(:probed) { "NONE" }

      it "raises a ValidRepoNotFound error" do
        expect { subject.packages }.to raise_error(Installation::UpdateRepository::ValidRepoNotFound)
      end
    end

    context "when the repository can't be probed" do
      let(:probed) { nil }

      it "raises a CouldNotProbeRepo error" do
        expect { subject.packages }.to raise_error(Installation::UpdateRepository::CouldNotProbeRepo)
      end
    end

    context "when repository cannot be refreshed" do
      before do
        allow(Yast::Pkg).to receive(:SourceRefreshNow).and_return(nil)
      end

      it "raises a CouldNotRefreshRepo error" do
        expect { subject.packages }.to raise_error(Installation::UpdateRepository::CouldNotRefreshRepo)
      end
    end

    context "when the repo does not have packages" do
      let(:packages) { [from_other_repo] }

      it "returns an empty array" do
        expect(repo.packages).to eq([])
      end
    end

    context "when the source contains packages" do
      let(:other_package) do
        { "name" => "pkg0", "path" => "./x86_64/pkg0-3.1.x86_64.rpm", "source" => repo_id }
      end

      let(:packages) { [package, from_other_repo, other_package] }

      it "returns update repository packages sorted by name" do
        expect(repo.packages).to eq([other_package, package])
      end
    end
  end

  describe "#fetch" do
    around do |example|
      FileUtils.mkdir_p([download_path, updates_path, tmpdir])
      example.run
      FileUtils.rm_rf(TEMP_DIR)
    end

    let(:package) do
      { "name" => "pkg1", "path" => "./x86_64/pkg1-3.1.x86_64.rpm", "source" => repo_id }
    end

    let(:libzypp_package_path) { "/var/adm/tmp/pkg1-3.1.x86_64.rpm" }
    let(:package_path) { "/var/adm/tmp/pkg1-3.1.x86_64.rpm" }
    let(:tempfile) { double("tempfile", close: true, path: package_path) }

    before do
      allow(repo).to receive(:add_repo).and_return(repo_id)
      allow(repo).to receive(:packages).and_return([package])
      allow(Dir).to receive(:mktmpdir).and_return(tmpdir.to_s)
    end

    it "builds one squashed filesystem by package" do
      allow(FileUtils).to receive(:cp).with(libzypp_package_path, package_path)
      allow(Tempfile).to receive(:new).and_return(tempfile)

      # Download
      expect(Yast::Pkg).to receive(:ProvidePackage)
        .with(repo_id, package["name"], kind_of(Yast::FunRef)) do |args|
          subject.send(:copy_file_to_tempfile, libzypp_package_path)
        end

      # Extract
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /rpm2cpio.*#{package_path}/)
        .and_return("exit" => 0, "stdout" => "", "stderr" => "")
      # Squash
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /mksquashfs.+#{tmpdir} .+\/yast_000/)
        .and_return("exit" => 0, "stdout" => "", "stderr" => "")

      repo.fetch(download_path)
    end

    context "when a package can't be retrieved" do
      before do
        allow(Yast::Pkg).to receive(:ProvidePackage).and_return(nil)
      end

      it "raises a CouldNotBeApplied error" do
        expect { repo.fetch(download_path) }.to raise_error(Installation::UpdateRepository::CouldNotBeApplied)
      end
    end
  end

  describe "#apply" do
    let(:update_path) { Pathname("/download/yast_000") }
    let(:mount_point) { updates_path.join("yast_0000") }
    let(:file) { double("file") }

    before do
      allow(repo).to receive(:paths).and_return([update_path])
    end

    it "mounts and adds files/dir" do
      allow(repo.instsys_parts_path).to receive(:open)
      expect(FileUtils).to receive(:mkdir).with(mount_point)
      # mount
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /mount.+#{update_path}.+#{mount_point}/)
        .and_return("exit" => 0)
      # adddir
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /adddir #{mount_point} \//)
        .and_return("exit" => 0)

      repo.apply(updates_path)
    end

    it "adds mounted filesystem to instsys.parts file" do
      allow(repo.instsys_parts_path).to receive(:open).and_yield(file)
      allow(FileUtils).to receive(:mkdir).with(mount_point)
      allow(Yast::SCR).to receive(:Execute)
        .with(any_args)
        .and_return("exit" => 0)
      expect(file).to receive(:puts).with(%r{\Adownload/yast_000.+yast_0000})
      repo.apply(updates_path)
    end
  end

  describe "#cleanup" do
    it "deletes the repository" do
      expect(Yast::Pkg).to receive(:SourceDelete).with(repo_id)
      subject.cleanup
    end
  end
end

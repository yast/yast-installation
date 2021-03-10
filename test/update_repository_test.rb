#!/usr/bin/env rspec

require_relative "test_helper"

require "installation/update_repository"
require "uri"
require "pathname"
require "stringio"

describe Installation::UpdateRepository do
  TEMP_DIR = Pathname.new(__FILE__).dirname.join("tmp")

  Yast.import "Pkg"

  subject(:repo) { Installation::UpdateRepository.new(uri) }

  let(:uri) { URI("http://updates.opensuse.org/sles12") }
  let(:repo_id) { 1 }
  let(:download_path) { TEMP_DIR.join("download") }
  let(:updates_path) { TEMP_DIR.join("mounts") }
  let(:probed) { "RPMMD" }
  let(:packages) { [] }

  before do
    allow(Yast::Pkg).to receive(:RepositoryProbe).with(uri.to_s, "/").and_return(probed)
    allow(Yast::Pkg).to receive(:RepositoryAdd)
      .with(hash_including("base_urls" => [uri.to_s]))
      .and_return(repo_id)
    allow(Yast::Pkg).to receive(:SourceRefreshNow).with(repo_id).and_return(true)
    allow(Yast::Pkg).to receive(:SourceLoad).and_return(true)
    allow(subject).to receive(:write_package_index)
    allow(repo).to receive(:write_package_index)
  end

  describe "#packages" do
    after { FileUtils.rm_rf(TEMP_DIR) }

    let(:package) do
      Y2Packager::Resolvable.new(
        "name"    => "pkg1",
        "version" => "3.2",
        "path"    => "./x86_64/pkg1-3.2.x86_64.rpm",
        "source"  => repo_id
      )
    end

    let(:same_package) do
      Y2Packager::Resolvable.new(
        "name"    => "pkg1",
        "version" => "3.1",
        "path"    => "./x86_64/pkg1-3.1.x86_64.rpm",
        "source"  => repo_id
      )
    end

    let(:other_package) do
      Y2Packager::Resolvable.new(
        "name"    => "pkg0",
        "version" => "3.1",
        "path"    => "./x86_64/pkg0-3.1.x86_64.rpm",
        "source"  => repo_id
      )
    end

    let(:from_other_repo) do
      Y2Packager::Resolvable.new(
        "name"    => "pkg2",
        "version" => "3.1",
        "path"    => "./x86_64/pkg2-3.1.x86_64.rpm",
        "source"  => repo_id + 1
      )
    end

    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :package, source: repo_id)
        .and_return([other_package, package, same_package])
      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :package, source: repo_id + 1)
        .and_return([from_other_repo])
    end

    context "when the repository type can't be determined" do
      let(:probed) { "NONE" }

      it "raises a NotValidRepo error" do
        expect { subject.packages }
          .to raise_error(Installation::UpdateRepository::NotValidRepo)
      end
    end

    context "when the repository can't be probed" do
      let(:probed) { nil }

      it "raises a CouldNotProbeRepo error" do
        expect { subject.packages }
          .to raise_error(Installation::UpdateRepository::CouldNotProbeRepo)
      end
    end

    context "when repository cannot be refreshed" do
      before do
        allow(Yast::Pkg).to receive(:SourceRefreshNow).and_return(nil)
      end

      it "raises a CouldNotRefreshRepo error" do
        expect { subject.packages }
          .to raise_error(Installation::UpdateRepository::CouldNotRefreshRepo)
      end
    end

    context "when the repo does not have packages" do
      it "returns an empty array" do
        expect(Y2Packager::Resolvable).to receive(:find).with(kind: :package, source: repo_id)
          .and_return([])
        expect(repo.packages).to eq([])
      end
    end

    context "when the source contains packages" do
      it "returns update repository packages sorted by name" do
        expect(repo.packages.map(&:name)).to eq([other_package.name, package.name])
      end
    end
  end

  describe "#fetch" do
    around do |example|
      FileUtils.mkdir_p([download_path, updates_path])
      example.run
      FileUtils.rm_rf(TEMP_DIR)
    end

    let(:package) do
      Y2Packager::Resolvable.new("name" => "pkg1", "path" => "./x86_64/pkg1-3.1.x86_64.rpm", "source" => repo_id)
    end

    let(:libzypp_package_path) { "/var/adm/tmp/pkg1-3.1.x86_64.rpm" }
    let(:package_path) { "/var/adm/tmp/pkg1-3.1.x86_64.rpm" }
    let(:tempfile) { double("tempfile", close: true, path: package_path, unlink: true) }
    let(:downloader) { double("Packages::PackageDownloader", download: nil) }
    let(:extractor) { double("Packages::PackageExtractor", extract: nil) }
    let(:self_update_archive) { fixtures_dir("self-update-content.tar.xz") }

    before do
      allow(repo).to receive(:add_repo).and_return(repo_id)
      allow(repo).to receive(:packages).and_return([package])
      allow(Packages::PackageDownloader).to receive(:new).with(repo_id, package.name)
        .and_return(downloader)
      allow(Packages::PackageExtractor).to receive(:new).with(tempfile.path.to_s)
        .and_return(extractor)
      allow(extractor).to receive(:extract) do |dir|
        FileUtils.mkdir_p(dir)
        system("/usr/bin/tar xf #{self_update_archive} -C #{dir}")
      end
      allow(Tempfile).to receive(:new).and_return(tempfile)
    end

    it "builds a squashed filesystem containing all updates" do
      # Download
      expect(downloader).to receive(:download).with(tempfile.path.to_s)

      # Squash
      expect(Yast::SCR).to receive(:Execute) do |*args|
        yast_path, command = args
        expect(yast_path).to eq(Yast::Path.new(".target.bash_output"))
        dir = command[/mksquashfs ([^ ]+) .+\/yast_000/, 1]
        tmpdir = Pathname.new(dir)
        squashed = tmpdir.glob("**/*")
        expect(squashed).to_not include(tmpdir.join("usr", "share", "doc"))
        expect(squashed).to_not include(tmpdir.join("usr", "share", "info"))
        expect(squashed).to_not include(tmpdir.join("usr", "share", "man"))
        expect(squashed).to_not include(tmpdir.join("usr", "share", "YaST2", "schema"))
        expect(squashed).to include(
          tmpdir.join("usr", "share", "YaST2", "lib", "installation", "sample.rb")
        )
      end.and_return("exit" => 0, "stdout" => "")

      repo.fetch(download_path)
    end

    context "when a package can't be retrieved" do
      before do
        allow(downloader).to receive(:download)
          .and_raise(Packages::PackageDownloader::FetchError)
      end

      it "raises a CouldNotFetchUpdate error" do
        expect { repo.fetch(download_path) }
          .to raise_error(Installation::UpdateRepository::CouldNotFetchUpdate)
      end
    end

    context "when a package can't be extracted" do
      it "raises a CouldNotFetchUpdate error" do
        expect(extractor).to receive(:extract)
          .and_raise(Packages::PackageExtractor::ExtractionFailed)

        expect { repo.fetch(download_path) }
          .to raise_error(Installation::UpdateRepository::CouldNotFetchUpdate)
      end
    end

    context "when a package can't be squashed" do
      it "raises a CouldNotFetchUpdate error" do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), /mksquash/)
          .and_return("exit" => 1, "stdout" => "", "stderr" => "")

        expect { repo.fetch(download_path) }
          .to raise_error(Installation::UpdateRepository::CouldNotFetchUpdate)
      end
    end
  end

  describe "#apply" do
    let(:updates_file) { Pathname("/download/yast_000") }
    let(:mount_point) { updates_path.join("yast_0000") }
    let(:file) { double("file") }
    let(:package) do
      Y2Packager::Resolvable.new("name" => "pkg1", "version" => "1.42-1.2", "arch" => "noarch")
    end

    before do
      allow(repo).to receive(:updates_file).and_return(updates_file)
      allow(Installation::UpdateRepository::INSTSYS_PARTS_PATH).to receive(:open).and_yield(file)
      allow(FileUtils).to receive(:mkdir_p).with(mount_point)
      allow(repo).to receive(:packages).and_return([package])
      allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0)
      allow(file).to receive(:puts)
    end

    it "mounts and adds files/dir" do
      # mount
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /mount.+#{updates_file}.+#{mount_point}/)
        .and_return("exit" => 0)
      # adddir
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), /adddir #{mount_point} \//)
        .and_return("exit" => 0)

      repo.apply(updates_path)
    end

    it "writes the list of updated packages to the #{Installation::UpdateRepository::PACKAGE_INDEX} file" do
      # deactivate the global mock
      expect(repo).to receive(:write_package_index).and_call_original

      io = StringIO.new
      expect(File).to receive(:open).with(Installation::UpdateRepository::PACKAGE_INDEX, "a").and_yield(io)
      repo.apply(updates_path)
      # check the written content
      expect(io.string).to eq("pkg1 [1.42-1.2.noarch]\n")
    end

    it "adds mounted filesystem to instsys.parts file" do
      allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0)
      expect(file).to receive(:puts).with(%r{\Adownload/yast_000.+yast_0000})
      repo.apply(updates_path)
    end

    context "when a squashed package can't be mounted" do
      it "raises a CouldNotMountUpdate error" do
        allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0)
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), /mount/)
          .and_return("exit" => 1, "stdout" => "", "stderr" => "")
        expect { repo.apply(updates_path) }
          .to raise_error(Installation::UpdateRepository::CouldNotMountUpdate)
      end
    end

    context "when files can't be added to inst-sys" do
      it "raises a CouldNotBeApplied error" do
        allow(Yast::SCR).to receive(:Execute).with(any_args).and_return("exit" => 0)
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), /adddir/)
          .and_return("exit" => 1, "stdout" => "", "stderr" => "")
        expect { repo.apply(updates_path) }
          .to raise_error(Installation::UpdateRepository::CouldNotBeApplied)
      end
    end
  end

  describe "#cleanup" do
    it "deletes and releases the repository" do
      expect(Yast::Pkg).to receive(:SourceDelete).with(repo_id)
      expect(Yast::Pkg).to receive(:SourceReleaseAll)
      expect(Yast::Pkg).to receive(:SourceSaveAll)

      subject.cleanup
    end
  end

  describe "#user_defined?" do
    context "when origin is :user" do
      subject(:repo) { Installation::UpdateRepository.new(uri, :user) }

      it "returns true" do
        expect(repo).to be_user_defined
      end
    end

    context "when origin is :default" do
      subject(:repo) { Installation::UpdateRepository.new(uri, :default) }

      it "returns false" do
        expect(repo).to_not be_user_defined
      end
    end

    context "when origin is not specified" do
      it "returns false" do
        expect(repo).to_not be_user_defined
      end
    end
  end

  describe "#remote?" do
    context "when is a remote URL according to libzypp" do
      it "returns true" do
        expect(Yast::Pkg).to receive(:UrlSchemeIsRemote).with("http")
          .and_call_original
        expect(repo).to be_remote
      end
    end

    context "when is not a remote URL according to libzypp" do
      let(:uri) { URI("cd:/?device=sr0") }

      it "returns false" do
        expect(Yast::Pkg).to receive(:UrlSchemeIsRemote).with("cd")
          .and_call_original
        expect(repo).to_not be_remote
      end
    end
  end

  describe "#inspect" do
    let(:uri) { URI("http://user:123456@updates.suse.com") }

    it "does not contain sensitive information" do
      expect(repo.inspect).to_not include("123456")
    end
  end

  describe "#to_s" do
    let(:uri) { URI("http://user:123456@updates.suse.com") }

    it "does not contain sensitive information" do
      expect(repo.to_s).to_not include("123456")
    end
  end
end



require "fileutils"
require "uri"

require "yast"
require "installation/selfupdate_addon_filter"
require "packages/package_downloader"

Yast.import "Directory"
Yast.import "Pkg"

module Installation
  class SelfupdateAddonRepo
    extend Yast::Logger

    REPO_PATH = File.join(Yast::Directory.vardir, "self_update_addon").freeze

    #
    # Create an addon repository from the self-update repository
    # containing specific packages. The repository is a plaindir type
    # and does not contain any metadata.
    #
    # @param repo_id [Integer] repo_id repository ID
    # @param path [String] path where to download the packages
    #
    # @return [Boolean] true if a repository has been created,
    #   false when no addon package was found in the self update repository
    #
    def self.copy_packages(repo_id, path = REPO_PATH)
      pkgs = Installation::SelfupdateAddonFilter.packages(repo_id)
      return false if pkgs.empty?

      log.info("Addon packages to download: #{pkgs}")

      ::FileUtils.mkdir_p(path)

      pkgs.each do |pkg|
        downloader = Packages::PackageDownloader.new(repo_id, pkg["name"])
        log.info("Downloading package #{pkg["name"]}...")
        downloader.download(File.join(path, pkg["name"])
      end

      log.debug { "Downloaded packages: #{Dir["#{path}/*"]}" }

      true
    end

    def self.present?(path = REPO_PATH)
      # the directory exists and is not empty
      ret = File.exist?(path) && !Dir.empty?(path)
      log.info("Repository #{path} exists: #{ret}")
      ret
    end

    def self.create_repo(path = REPO_PATH)
      # create a plaindir repository, there is no package metadata
      ret = Yast::Pkg.SourceCreateType("dir://#{URI.escape(path)}", "", "Plaindir")
      log.info("Created self update addon repo: #{ret}")
      ret
    end

  end
end

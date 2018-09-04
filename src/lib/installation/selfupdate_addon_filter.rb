

require "yast"

Yast.import "Pkg"

module Installation
  class SelfupdateAddonFilter

    PROVIDES_INSTALLATION = "system-installation()".freeze

    #
    # Returns package name from the selected repository which should be used
    # in an update repository instead of applying to the ins-sys.
    #
    # @param repo_id [Integer] the self-update repository ID
    # @return [Array<String>] the list of packages which should be used
    #   in an addon repository
    #
    def self.packages(repo_id)

      # returns list like [["skelcd-control-SLED", :CAND, :NONE],
      # ["skelcd-control-SLES", :CAND, :NONE],...]
      skelcds = Yast::Pkg.PkgQueryProvides(PROVIDES_INSTALLATION)

      pkgs = skelcds.map{ |s| s.first}.uniq

      # there should not be present any other repository except the self update at this point,
      # but rather be safe than sorry...

      pkgs.select! do |pkg|
        props = Yast::Pkg.ResolvableProperties(pkg, :package, "")
        props.any?{|p| p["source"] == repo_id}
      end

      log.info "Found addon packages in the self update repository: #{pkgs}"

      pkgs
    end
  end
end

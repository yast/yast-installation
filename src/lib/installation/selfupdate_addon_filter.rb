module Installation
  class SelfupdateAddonFilter

    #
    # Returns a filtering lambda function
    #
    # @return [lambda] the filter
    #
    def self.filter
      # The "pkg" parameter is a single package from the Pkg.ResolvableDependencies() call
      lambda do |pkg|
        deps = pkg["deps"] || []

        deps.any? do |d|
          # Example dependency: {"provides"=>"system-installation() = SLES"}
          d["provides"] && d["provides"].start_with?("system-installation()")
        end
      end
    end
  end
end
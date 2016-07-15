require "singleton"
require "yast"

module Installation
  # Wrapper around minimal installation configuration.
  #
  # Now supported only in autoyast
  class MinimalInstallation
    include Singleton
    include Yast::Logger

    def enabled
      return @enabled unless @enabled.nil?

      Yast.import "Mode"
      if Yast::Mode.autoinst
        Yast.import "Profile"
        profile = Yast::Profile.current
        @enabled = if profile["general"] && profile["general"]["minimal-configuration"]
          true
        else
          false
        end
      else
        @enabled = false
      end

      log.info "Minimal installation enabled?: #{@enabled}"

      @enabled
    end
    alias_method :enabled?, :enabled
  end
end

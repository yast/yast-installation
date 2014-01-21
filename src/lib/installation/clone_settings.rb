require "singleton"

module Installation
  # helper module to make proposal value persistent
  class CloneSettings
    include Singleton

    attr_accessor :enabled
    alias_method :enabled?, :enabled
  end
end

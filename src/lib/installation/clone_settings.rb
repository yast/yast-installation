module Installation
  # helper module to make proposal value persistent
  class CloneSettings
    include Singleton

    attr_accessor :enabled
    method_alias :enabled?, :enabled
  end
end

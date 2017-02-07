require "yast"

Yast.import "PackagesUI"

module Installation
  class CustomPatterns
    class << self
      # flag if custom patters should be shown
      attr_accessor :show
    end

    def run
      if self.class.show
        ret = Yast::PackagesUI.RunPatternSelector
        ret = :next if ret == :accept
      else
        ret = :auto
      end
    end
  end
end

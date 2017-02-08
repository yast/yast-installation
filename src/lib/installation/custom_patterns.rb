require "yast"

Yast.import "PackagesUI"
Yast.import "Label"

module Installation
  class CustomPatterns
    class << self
      # flag if custom patterns should be shown
      attr_accessor :show
    end

    def run
      if self.class.show
        ret = Yast::PackagesUI.RunPatternSelector(enable_back: true, cancel_label: Yast::Label.AbortButton)
        ret = :next if ret == :accept
      else
        ret = :auto
      end

      ret
    end
  end
end

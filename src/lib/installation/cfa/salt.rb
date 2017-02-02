require "cfa/base_model"
require "cfa/augeas_parser"
require "cfa/matcher"

module Installation
  module CFA
    # Represents a Salt Minion master configuration file.
    class MinionMasterConf < ::CFA::BaseModel
      attributes(master: "master")

      # Configuration parser
      PARSER = ::CFA::AugeasParser.new("cobblersettings.lns")
      # Path to configuration file
      PATH = "/etc/salt/minion.d/master.conf".freeze

      # Constructor
      #
      # @param file_handler [.read, .write, nil] an object able to read/write a string.
      def initialize(file_handler: nil)
        super(PARSER, PATH, file_handler: file_handler)
      end
    end
  end
end

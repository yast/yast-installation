#! /usr/bin/env rspec

require_relative "./test_helper"
require_relative "../src/include/installation/misc"

# a testing class for includign the "misc" include
class InstallationMiscIncludeTest
  include Yast::InstallationMiscInclude
end

describe Yast::InstallationMiscInclude do
  pending
end

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "yast"

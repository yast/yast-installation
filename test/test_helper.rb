srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "yast"

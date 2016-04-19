srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

require "yast"
require "yast/rspec"

# fake AutoinstConfigClass class which is not supported by Ubuntu
module Yast
  # Faked AutoinstConfigClass module
  class AutoinstConfigClass
    # we need at least one non-default methods, otherwise ruby-bindings thinks
    # it is just namespace
    def cio_ignore
    end

    def second_stage
    end
  end
  AutoinstConfig = AutoinstConfigClass.new

  # Faked Profile module
  class Profile
    def current
    end
  end
  Profile = Profile.new
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  # For coverage we need to load all ruby files
  # Note that clients/ are excluded because they run too eagerly by
  # design
  Dir["#{srcdir}/{include,lib,modules}/**/*.rb"].each do |f|
    require_relative f
  end

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end

RSpec.configure do |config|
  config.extend Yast::I18n  # available in context/describe
  config.include Yast::I18n # available in it/let/before/...
end

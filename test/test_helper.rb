srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

# make sure we run the tests in English locale
# (some tests check the output which is marked for translation)
ENV["LC_ALL"] = "en_US.UTF-8"
# fail fast if a class does not declare textdomain (bsc#1130822)
ENV["Y2STRICTTEXTDOMAIN"] = "1"

require "yast"
require "yast/rspec"
require "pathname"
require_relative "helpers"

FIXTURES_DIR = Pathname.new(__FILE__).dirname.join("fixtures")

# mock some dependencies, to not increase built dependencies
$LOAD_PATH.unshift(File.join(FIXTURES_DIR.to_s, "stub_libs"))

# stub module to prevent its Import
# Useful for modules from different yast packages, to avoid build dependencies
def stub_module(name)
  Yast.const_set name.to_sym, Class.new { def self.fake_method; end }
end

# stub classes from other modules to speed up a build
stub_module("AddOnProduct")
stub_module("AutoinstConfig")
stub_module("AutoinstGeneral")
stub_module("Console")
stub_module("InstURL")
stub_module("Keyboard")
stub_module("Language")
stub_module("Packages")
stub_module("ProductLicense")
stub_module("Profile")
stub_module("ProfileLocation")
# we cannot depend on this module (circular dependency)
stub_module("NtpClient")

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  bindir = File.expand_path("../../bin", __FILE__)
  # For coverage we need to load all ruby files
  SimpleCov.track_files("{#{srcdir}/**/*.rb,#{bindir}/{yupdate,memsample-archive-to-csv}}")

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
  config.include Helpers    # custom helpers
end

# require the "bin/yupdate" script for testing it, unfortunately we cannot use
# a simple require/require_relative for it, let's share the workaround in a single place
def require_yupdate
  # - "require"/"require_relative" do not work for files without the ".rb" extension
  # - adding the "yupdate.rb" -> "yupdate" symlink works but then code coverage
  #   somehow does not find the executed code and reports zero coverage there
  # - "load" works fine but we need to ensure calling it only once
  #   to avoid the "already initialized constant" Ruby warnings
  load File.expand_path("../bin/yupdate", __dir__) unless defined?(YUpdate)
end

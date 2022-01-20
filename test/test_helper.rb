srcdir = File.expand_path("../src", __dir__)
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

# mock some dependencies, to not increase build dependencies
$LOAD_PATH.unshift(File.join(FIXTURES_DIR.to_s, "stub_libs"))

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  bindir = File.expand_path("../bin", __dir__)
  # For coverage we need to load all ruby files
  SimpleCov.track_files("{#{srcdir}/**/*.rb,#{bindir}/{yupdate,memsample-archive-to-csv}}")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end

RSpec.configure do |config|
  config.extend Yast::I18n  # available in context/describe
  config.include Yast::I18n # available in it/let/before/...
  config.include Helpers    # custom helpers

  config.mock_with :rspec do |c|
    # verify that the mocked methods actually exist
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    c.verify_partial_doubles = true
  end
end

# stub YaST modules to prevent importing them,
# useful for modules from different yast packages to avoid build dependencies
Yast::RSpec::Helpers.define_yast_module("AddOnProduct", methods: [:selected_installation_products])
Yast::RSpec::Helpers.define_yast_module("AutoinstConfig", methods: [:cio_ignore, :second_stage])
Yast::RSpec::Helpers.define_yast_module("AutoinstGeneral",
  methods: [:self_update, :self_update_url])
Yast::RSpec::Helpers.define_yast_module("AutoinstSoftware")
Yast::RSpec::Helpers.define_yast_module("Console")
Yast::RSpec::Helpers.define_yast_module("InstURL", methods: [:installInf2Url])
Yast::RSpec::Helpers.define_yast_module("Keyboard")
Yast::RSpec::Helpers.define_yast_module("Language", methods: [:language])
Yast::RSpec::Helpers.define_yast_module("NtpClient",
  methods: [:modified=, :ntp_conf, :ntp_selected=, :run_service=, :synchronize_time=])
Yast::RSpec::Helpers.define_yast_module("Packages",
  methods: [:GetBaseSourceID, :Reset, :SelectSystemPackages, :SelectSystemPatterns,
            :check_remote_installation_packages, :init_called])
Yast::RSpec::Helpers.define_yast_module("ProductLicense")
Yast::RSpec::Helpers.define_yast_module("Profile", methods: [:current])
Yast::RSpec::Helpers.define_yast_module("ProfileLocation")
Yast::RSpec::Helpers.define_yast_module("Proxy",
  methods: [:Export, :Import, :WriteCurlrc, :WriteSysconfig, :modified, :to_target])

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

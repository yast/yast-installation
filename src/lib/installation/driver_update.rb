require "yast"
require "tempfile"
require "open-uri"

module Installation
  # Represents a driver update disk (DUD)
  #
  # The DUD will be fetched from a remote URL. At this time, only HTTP/HTTPS
  # are supported.
  class DriverUpdate
    EXTRACT_CMD = "gzip -dc %<source>s | cpio --quiet --sparse -dimu --no-absolute-filenames"
    APPLY_CMD = "/etc/adddir %<source>s/inst-sys /"
    FETCH_CMD = "/usr/bin/curl --location --verbose --fail --max-time 300 --connect-timeout 15 " \
      "%<uri>s --output '%<output>s'"
    TEMP_FILENAME = "remote.dud"

    attr_reader :uri, :local_path

    # Constructor
    #
    # @param uri        [URI]      DUD's URI
    def initialize(uri)
      @uri = uri
      @local_path = nil
      Yast.import "Linuxrc"
    end

    # Fetch the DUD and stores it in the given directory
    #
    # Retrieves and extract the DUD to the given directory.
    #
    # @param target [Pathname] Directory to extract the DUD to.
    #
    # FIXME: should it be called by the constructor?
    def fetch(target)
      @local_path = target
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          temp_file = Pathname.pwd.join(TEMP_FILENAME)
          download_file_to(temp_file)
          extract(temp_file, local_path)
        end
      end
    end

    # Apply the DUD to the running system
    #
    # @return [Boolean] true if the DUD was applied; false otherwise.
    #
    # FIXME: remove the ! sign
    # FIXME: handle update.{pre,post} scripts
    def apply!
      raise "Not fetched yet!" if local_path.nil?
      adddir
      run_update_pre
    end

    private

    # Extract the DUD at 'source' to 'target'
    #
    # @param source [Pathname]
    #
    # @see EXTRACT_CMD
    def extract(source, target)
      cmd = format(EXTRACT_CMD, source: source)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      raise "Could not extract DUD" unless out["exit"].zero?
      setup_target(target)
      FileUtils.mv(update_dir, target)
    end

    # Set up the target directory
    #
    # Refresh the target directory (re-creates it)
    #
    # @param dir [Pathname] Directory to re-create
    def setup_target(dir)
      FileUtils.rm_r(dir) if dir.exist?
      FileUtils.mkdir_p(dir.dirname) unless dir.dirname.exist?
    end

    # Download the DUD to a file
    #
    # @return [True] True if download was successful
    def download_file_to(path)
      cmd = format(FETCH_CMD, uri: uri, output: path)
      Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      raise NotFound unless path.exist?
      true
    end

    # Directory which contains files within the DUD
    #
    # @see UpdateDir value at /etc/install.inf.
    def update_dir
      path = Pathname.new(Yast::Linuxrc.InstallInf("UpdateDir"))
      path.relative_path_from(Pathname.new("/"))
    end

    def adddir
      cmd = format(APPLY_CMD, source: local_path)
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
      out["exit"].zero?
    end

    # Run update.pre script
    #
    # @return [Boolean,NilClass] true if execution was successful; false if
    #                            it failed; nil if script does not exist or
    #                            was not executable.
    def run_update_pre
      update_pre_path = local_path.join("install", "update.pre")
      return nil unless update_pre_path.exist? && update_pre_path.executable?
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), update_pre_path.to_s)
      out["exit"].zero?
    end

  end
end

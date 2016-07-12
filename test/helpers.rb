module Helpers
  # Return path to a fixture directory
  #
  # @example Get the base fixtures directory
  #   fixtures_dir #=> FIXTURES_DIR
  #
  # @example Get a determined fixture directory
  #   fixtures_dir("fix1") #=> FIXTURES_DIR.join("fix1")
  #
  # @param *dirs [Array<String>] Components of path within fixtures directory
  # @return [Pathname] Pathname to fixture dir
  def fixtures_dir(*dirs)
    FIXTURES_DIR.join(*dirs)
  end

  # Read the fixture file
  # @param *path [Array<String>] path components
  # @see fixtures_dir
  # @return [String] the loaded file
  def load_fixture(*path)
    File.read(fixtures_dir(*path))
  end
end

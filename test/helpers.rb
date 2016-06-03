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
end

require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/

  conf.install_locations["autoyast_desktop/*.desktop"] = Packaging::Configuration::DESTDIR + "/usr/share/autoinstall/modules"
  # TODO: move to src/client and verify if needed
  conf.install_locations["control/*.rb"] = Packaging::Configuration::YAST_DIR + "/clients"
  conf.install_locations["startup"] = Packaging::Configuration::YAST_LIB_DIR
end

# safety check - make sure the RNG file is up to date
task :check_rng_status do
  # get the timestamps for the last commits
  rnc_commit_time = `git log -1 --format="%ct" -- control/control.rnc`
  rng_commit_time = `git log -1 --format="%ct" -- control/control.rng`

  # RNC must not be newer than RNG
  if rng_commit_time.to_i < rnc_commit_time.to_i
    raise "Error: control/control.rng is outdated, regenerate it from control/control.rnc file"
  end
end

task tarball: :check_rng_status

require "yast/rake"

Yast::Tasks.configuration do |conf|
  conf.obs_api = "https://api.suse.de/"
  conf.obs_target = "SLE_12"
  conf.obs_sr_project = "SUSE:SLE-12:Update:Test"
  conf.obs_project = "Devel:YaST:SLE-12"
  #lets ignore license check for now
  conf.skip_license_check << /.*/
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

task :tarball => :check_rng_status


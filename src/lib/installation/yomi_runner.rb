# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "pathname"
require "fileutils"
require "yaml"
require "yast2/execute"
require "yast2/systemd/service"

module Installation
  class YomiRunner
    attr_reader :root_path

    ROOT_PATH = Pathname.new("/").freeze

    def initialize(root_path: ROOT_PATH)
      @root_path = root_path
    end

    def config_dir
      @config_dir ||= root_path.join("etc", "salt")
    end

    def pillar_path
      @pillar_path ||= root_path.join("srv", "pillar", "installer.sls")
    end

    def _run_local_mode(pillar)
      # salt-call
      # write minion.d files to point to yomi
      # write the pillar to /srv/pillar/installer.sls
      # run yomi
    end

    def run_master_mode(pillar)
      # salt-master
      # the configuration is already in place because yomi-formula is installed
      # set up authentication (auto sign-in)
      # start the master
      # write the pillar to /srv/pillar/installer.sls
      # run yomi (salt 'name' stage.apply)
      prepare_autosign
      prepare_minion
      prepare_pillar(pillar)
      prepare_top
      start_service("salt-master")
      # FIXME
      sleep 5
      start_service("salt-minion")
      # FIXME
      sleep 10
      Yast::Execute.locally!("salt", "*", "state.apply", "--async")
    end

  private

    # Enables autosign feature by using the machine_id
    def prepare_autosign
      # master
      autosign_grains_dir = config_dir.join('autosign_grains')
      File.write(
        config_dir.join('master.d', 'autosign.conf'),
        "autosign_grains_dir: #{autosign_grains_dir}"
      )

      FileUtils.mkdir_p(autosign_grains_dir) unless autosign_grains_dir.exist?

      # write the uuid
      File.write(autosign_grains_dir.join('uuid'), uuid)

      # minion
      File.write(
        config_dir.join('minion.d', 'autosign.conf'),
        YAML.dump("autosign_grains" => ["uuid"])
      )
    end

    # TODO: read from "dmidecode | grep -i uuid"
    def uuid
      machine_id = File.read("/etc/machine-id")
      machine_id.unpack("A8A4A4A4A16").join("-")
    end

    def prepare_minion
      File.write(
        config_dir.join('minion.d', 'yast.conf'),
        YAML.dump("master" => "localhost")
      )
    end

    # Writes the pillar data to the pillar path
    def prepare_pillar(pillar_data)
      FileUtils.cp("/usr/share/yomi/pillar.conf", config_dir.join("master.d"))
      pillar_dir = pillar_path.dirname
      FileUtils.mkdir_p(pillar_dir) unless pillar_dir.exist?
      File.write(pillar_path, YAML.dump(pillar_data))
    end

    def prepare_top
      top_path = root_path.join("srv", "salt", "top.sls")
      hash = { "base" => { "*" => ["yomi"] } }
      File.write(top_path, YAML.dump(hash))
    end

    def start_service(name)
      service = Yast2::Systemd::Service.find(name)
      return if service.running?

      service.start
    end
  end
end

# root_path = Pathname.new("/tmp/root")
# runner = Installation::YomiRunner.new(root_path: root_path)
# runner.run_master_mode("partitions" => [])

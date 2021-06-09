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
    include Yast::Logger

    attr_reader :root_dir, :data_dir

    ROOT_DIR = Pathname.new("/").freeze
    DATA_DIR = Pathname.new(__FILE__).join("..", "..", "..", "data", "installation").freeze

    def initialize(root_dir: ROOT_DIR, data_dir: DATA_DIR)
      @root_dir = root_dir
      @data_dir = data_dir
    end

    # Starts Salt in master/minion mode
    #
    # * Sets up the authentication (auto sign-in) using the machine ID
    # * Sets up the minion to connect to localhost
    # * Write the installer's data to /srv/pillar/installer.sls
    # * Prepare the /srv/salt/top.sls file
    # * Sets up the Salt API configuration
    # * Start master, minion, and API services
    #
    # @param pillar [Hash] Pillar data
    def start_salt(pillar)
      prepare_autosign
      prepare_minion
      prepare_pillar(pillar)
      prepare_top
      prepare_salt_api
      start_service("salt-master")
      start_service("salt-minion")
      start_service("salt-api")
    end

    YOMI_MAX_ATTEMPTS = 3
    private_constant :YOMI_MAX_ATTEMPTS

    # Starts Yomi
    #
    # It starts Yomi by applying the salt states
    def start_yomi
      retries ||= 1
      Yast::Execute.locally!("salt", "*", "state.apply", "--async")
    rescue Cheetah::ExecutionFailed => e
      log.error("Error (#{retries}/#{YOMI_MAX_ATTEMPTS}): #{e}")
      sleep 1
      retries += 1
      retry unless retries > YOMI_MAX_ATTEMPTS
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
      FileUtils.cp(root_dir.join("usr", "share", "yomi", "pillar.conf"), config_dir.join("master.d"))
      pillar_dir = pillar_path.dirname
      FileUtils.mkdir_p(pillar_dir) unless pillar_dir.exist?
      File.write(pillar_path, YAML.dump(pillar_data))
    end

    def prepare_top
      top_path = root_dir.join("srv", "salt", "top.sls")
      hash = { "base" => { "*" => ["yomi"] } }
      File.write(top_path, YAML.dump(hash))
    end

    def prepare_salt_api
      FileUtils.cp(data_dir.join("eauth.conf"), config_dir.join("master.d", "eauth.conf"))
      FileUtils.cp(data_dir.join("salt-api.conf"), config_dir.join("master.d", "salt-api.conf"))
      File.write(config_dir.join("user-list.txt"), "salt:linux") # TODO
    end

    def start_service(name)
      service = Yast2::Systemd::Service.find(name)
      return if service.running?

      service.start
    end

    def config_dir
      @config_dir ||= root_dir.join("etc", "salt")
    end

    def pillar_path
      @pillar_path ||= root_dir.join("srv", "pillar", "installer.sls")
    end
  end
end

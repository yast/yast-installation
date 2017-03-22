module Installation
  module SystemRoleHandlers
    class WorkerRoleFinish
      include Yast::Logger

      def run
        role = SystemRole.find("worker_role")
        master_conf = CFA::MinionMasterConf.new
        master = role["controller_node"]
        begin
          master_conf.load
        rescue Errno::ENOENT
          log.info("The minion master.conf file does not exist, it will be created")
        end
        log.info("The controller node for this worker role is: #{master}")
        # FIXME: the cobblersettings lense does not support dashes in the url
        # without single quotes, we need to use a custom lense for salt conf.
        # As Salt can use also 'url' just use in case of dashed.
        master_conf.master = master.include?("-") ? "'#{master}'" : master
        master_conf.save
      end
    end
  end
end

# File:    pre_umount_finish.rb
#
# Module:  Step of base installation finish
#

require "yast"

require "installation/finish_client"

module Installation
  class PreUmountFinish < ::Installation::FinishClient
    include Yast::I18n

    def initialize
      textdomain "installation"
      Yast.import "UI"
      Yast.import "Misc"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Pkg"
      Yast.import "Mode"
    end

    def title
      _("Checking the installed system...")
    end

    def modes
      [:installation, :live_installation, :update, :autoinst]
    end

    def write
      Yast.include self, "installation/inst_inc_first.rb"

      # bugzilla #326478
      # some processes might be still running...
      cmd_run = WFM.Execute(path(".local.bash_output"),
        "/usr/bin/fuser -v '#{String.Quote(Installation.destdir)}' 2>&1")

      log.info("These processes are still running at " \
        "#{Installation.destdir} -> #{cmd_run}")

      unless Misc.boot_msg.empty?
        # just a beep
        SCR.Execute(path(".target.bash"), "/usr/bin/echo -e 'a'")
      end

      # creates or removes the runme_at_boot file (for second stage)
      # according to the current needs
      #
      # Must be called before 'umount'!
      #
      # See FATE #303396
      HandleSecondStageRequired()

      # Release all sources, they might be still mounted
      Pkg.SourceReleaseAll

      # save all sources and finish target
      # bnc #398315
      Pkg.SourceSaveAll
      Pkg.TargetFinish

      # BNC #692799: Preserve the randomness state before umounting
      preserve_randomness_state
    end

  private

    # Calls a local command and returns if successful
    def local_command(command)
      ret = WFM.Execute(path(".local.bash_output"), command)
      log.info "Command #{command} returned: #{ret}"
      return true if ret["exit"] == 0
      err = ret["stderr"]
      log.error "Error: #{err}" unless err.empty?
      false
    end

    # Reads and returns the current poolsize from /proc.
    # Returns integer size as a string.
    def read_poolsize
      poolsize_path = "/proc/sys/kernel/random/poolsize"

      poolsize = Convert.to_string(
        WFM.Read(path(".local.string"), poolsize_path)
      )

      if poolsize.nil? || poolsize == ""
        log.warn "Cannot read poolsize from #{poolsize_path}, using the default"
        poolsize = "4096"
      else
        poolsize = Builtins.regexpsub(poolsize, "^([[:digit:]]+).*", "\\1")
      end

      log.info "Using random/poolsize: #{poolsize}"
      poolsize
    end

    RANDOM_PATH = "/dev/urandom".freeze
    # Preserves the current randomness state, BNC #692799
    def preserve_randomness_state
      if Mode.update
        log.info("Not saving current random seed - in update mode")
        return
      end

      log.info "Saving the current randomness state..."

      store_to = "#{Installation.destdir}/var/lib/misc/random-seed"

      # Copy the current state of random number generator to the installed system
      if local_command(
        "/usr/bin/dd if='#{String.Quote(RANDOM_PATH)}' bs='#{String.Quote(read_poolsize)}' count=1 of='#{String.Quote(store_to)}'"
      )
        log.info "State of #{RANDOM_PATH} has been successfully copied to #{store_to}"
      else
        log.info "Cannot store #{RANDOM_PATH} state to #{store_to}"
      end
    end
  end
end

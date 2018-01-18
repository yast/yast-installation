# storage-ng
#
# This is apparently used to shrink all (?!) PReP partitions on CHRP (?!)
# machines to 8 MiB.
#
# Not sure what this tries to achieve nor why this deserved its own client.
#

module Installation
  class PrepShrinkFinish
    include Yast::Logger
    include Yast::I18n

    USABLE_WORKFLOWS = [
      :installation,
      :live_installation,
      :autoinst,
      :update,
      :autoupg # TODO: is autoupgrade still live?
    ].freeze

    YAST_BASH_PATH = Yast::Path.new ".target.bash_output"

    def initialize
      textdomain "installation"
    end

    def run(*args)
      func = args.first
      param = args[1] || {}

      log.debug "prep shrink finish client called with #{func} and #{param}"

      case func
      when "Info"
        Yast.import "Arch"
        usable = Yast::Arch.board_chrp

        {
          "steps" => 1,
          # progress step title
          "title" => _("Shrinking PREP partition..."),
          "when"  => usable ? USABLE_WORKFLOWS : []
        }

      when "Write"
        shrink_partitions

        nil
      else
        raise "Uknown action #{func} passed as first parameter"
      end
    end

  private

    MAXIMAL_SIZE_KB = 8192
    def shrink_partitions
# storage-ng
# rubocop:disable Style/BlockComments
=begin
      target_map = Yast::Storage.GetTargetMap
      target_map.each do |_disk, disk_values|
        (disk_values["partitions"] || []).each do |part_values|
          next unless need_shrink?(part_values)

          cmd = shrink_command(disk_values, part_values)
          log.info "shrinking command #{cmd}"
          Yast::SCR.Execute(YAST_BASH_PATH, cmd)
        end
      end
=end
    end

    # 0x41 is PPC PREP Boot
    # 0x108 is DOS PREP boot
    PREP_IDS = [0x41, 0x108].freeze
    def need_shrink?(partition)
      PREP_IDS.include?(partition["fsid"]) &&
        partition["size_k"] > MAXIMAL_SIZE_KB
    end

    def shrink_command(disk_values, part_values)
      cmd = "parted -s -a minimal "
      cmd << disk_values["device"]
      cmd << " resize "
      cmd << part_values["nr"].to_s
      cmd << " #{MAXIMAL_SIZE_KB}k"
    end
  end
end

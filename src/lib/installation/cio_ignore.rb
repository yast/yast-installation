require "yast"

module Installation
  class CIOIgnore
    include Singleton
    attr_accessor :enabled

    def initialize
      reset
    end

    def reset
      #default value requested in FATE#315586
      @enabled = true
    end
  end

  class CIOIgnoreProposal
    include Yast::Logger
    include Yast::I18n

    CIO_ENABLE_LINK = "cio_enable"
    CIO_DISABLE_LINK = "cio_disable"
    CIO_ACTION_ID = "cio"

    def initialize
      textdomain "installation"
    end

    def run(*args)
      func = args.first
      param = args[1] || {}

      log.debug "cio ignore proposal client called with #{func} and #{param}"

      case func
      when "MakeProposal"
        proposal_entry
      when "Description"
        {
          # this is a heading
          "rich_text_title" => _("Blacklist Devices"),
          # this is a menu entry
          "menu_title"      => _("B&lacklist Devices"),
          "id"              => CIO_ACTION_ID
        }
      when "AskUser"
        edit param["chosen_id"]
      else
        raise "Uknown action passed as first parameter"
      end
    end

  private

    def proposal_entry
      Yast.import "HTML"
      enabled = CIOIgnore.instance.enabled

      text = if enabled
               # TRANSLATORS: Installation overview
               # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
               (_(
                   "Blacklist devices enabled (<a href=\"%s\">disable</a>)."
                 ) % CIO_DISABLE_LINK)
             else
               # TRANSLATORS: Installation overview
               # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
               (_(
                   "Blacklist devices disabled (<a href=\"%s\">enable</a>)."
                 ) % CIO_ENABLE_LINK)
             end

      {
        "preformatted_proposal" => Yast::HTML.List([text]),
        "links"                 => [CIO_ENABLE_LINK, CIO_DISABLE_LINK],
        # TRANSLATORS: help text
        "help"                  => _(
          "<p>Use <b>Blacklist devices</b> if you want to create blacklist channels to such devices which will reduce kernel memory footprint.</p>"
        )
      }
    end

    def edit edit_id
      raise "Internal error: no id passed to proposal edit" unless edit_id

      log.info "CIO proposal change requested, id #{edit_id}"

      cio_ignore = CIOIgnore.instance

      cio_ignore.enabled = case edit_id
        when CIO_DISABLE_LINK then false
        when CIO_ENABLE_LINK  then true
        when CIO_ACTION_ID    then !cio_ignore.enabled
        else
          raise "INTERNAL ERROR: Unexpected value #{edit_id}"
        end

      { "workflow_sequence" => :next }
    end
  end

  class CIOIgnoreFinish
    include Yast::Logger
    include Yast::I18n

    USABLE_WORKFLOWS = [
      :installation,
      :live_installation,
      :autoinst
    ]

    YAST_BASH_PATH = Yast::Path.new ".target.bash_output"

    def initialize
      textdomain "installation"
    end

    def run(*args)
      func = args.first
      param = args[1] || {}

      log.debug "cio ignore finish client called with #{func} and #{param}"

      case func
      when "Info"
        Yast.import "Arch"
        usable = Yast::Arch.s390()

        {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Blacklisting Devices..."
          ),
          "when"  => usable ? USABLE_WORKFLOWS : []
        }

      when "Write"
        return nil unless CIOIgnore.instance.enabled

        res = Yast::SCR.Execute(YAST_BASH_PATH, "cio_ignore --unused --purge")

        log.info "result of cio_ignore call: #{res.inspect}"

        if res["exit"] != 0
          raise "cio_ignore command failed with stderr: #{res["stderr"]}"
        end

        # add kernel parameters that ensure that ipl and console device is never
        # blacklisted (fate#315318)
        add_boot_kernel_parameters

        # store activelly used devices to not be blocked
        store_active_devices

        nil
      else
        raise "Uknown action #{func} passed as first parameter"
      end
    end

  private

    def add_boot_kernel_parameters
      Yast.import "Bootloader"

      res = Yast::Bootloader.Read

      res &&= Yast::Bootloader.modify_kernel_params("cio_ignore" => "all,!ipldev,!condev")

      res &&= Yast::Bootloader.Write

      raise "failed to write kernel parameters for IPL and console device" if !res
    end

    ACTIVE_DEVICES_FILE = "/boot/zipl/active_devices.txt"
    def store_active_devices
      Yast.import "Installation"
      res = Yast::SCR.Execute(YAST_BASH_PATH, "cio_ignore -L")
      log.info "active devices: #{res}"

      raise "cio_ignore -L failed with #{res["stderr"]}" if res["exit"] != 0
      #lets select only lines that looks like device. Regexp is not perfect, but good enough
      devices_lines = res["stdout"].lines.grep(/^(?:\h.){0,2}\h{4}.*$/)

      devices = devices_lines.map(&:chomp)
      target_file = File.join(Yast::Installation.destdir, ACTIVE_DEVICES_FILE)

      # make sure the file ends with a new line character
      devices << "" unless devices.empty?

      File.write(target_file, devices.join("\n"))
    end
  end
end

require "yast"

module Installation
  class CIOIgnore
    # FIXME
    # The class name is a bit outdated now that it handles both cio_ignore
    # and rd.zdev kernel parameters.
    include Singleton
    include Yast::Logger
    Yast.import "Mode"
    Yast.import "AutoinstConfig"

    attr_accessor :cio_enabled
    attr_accessor :autoconf_enabled

    def initialize
      reset
    end

    def reset
      @autoconf_enabled = autoconf_setting
      @cio_enabled = cio_setting
    end

  private

    def kvm?
      File.exist?("/proc/sysinfo") &&
        File.readlines("/proc/sysinfo").grep(/Control Program: KVM\/Linux/).any?
    end

    def zvm?
      File.exist?("/proc/sysinfo") &&
        File.readlines("/proc/sysinfo").grep(/Control Program: z\/VM/).any?
    end

    # Get current I/O device autoconf setting (rd.zdev kernel option)
    #
    # @return [Boolean]
    def autoconf_setting
      Yast.import "Bootloader"

      rd_zdev = Yast::Bootloader.kernel_param(:common, "rd.zdev")
      log.info "current rd.zdev setting: rd.zdev=#{rd_zdev.inspect}"

      rd_zdev != "no-auto"
    end

    # Get current device blacklist setting (cio_ignore kernel option)
    #
    # @return [Boolean]
    def cio_setting
      if Yast::Mode.autoinst
        Yast::AutoinstConfig.cio_ignore
      elsif kvm? || zvm?
        # cio_ignore does not make sense for KVM or z/VM (fate#317861)
        false
      else
        # default value requested in FATE#315586
        true
      end
    end
  end

  class CIOIgnoreProposal
    include Yast::Logger
    include Yast::I18n

    CIO_ENABLE_LINK = "cio_enable".freeze
    CIO_DISABLE_LINK = "cio_disable".freeze
    AUTOCONF_ENABLE_LINK = "autoconf_enable".freeze
    AUTOCONF_DISABLE_LINK = "autoconf_disable".freeze
    ACTION_ID = "cio".freeze

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
          "rich_text_title" => _("Device Settings"),
          # this is a menu entry
          "menu_title"      => _("Device Settings"),
          "id"              => ACTION_ID
        }
      when "AskUser"
        edit param["chosen_id"]
      else
        raise "Unknown action passed as first parameter"
      end
    end

  private

    # Build HTML text with clickable on/off-link.
    #
    # @param what [String] short text describing what to toggle
    # @param state [Boolean] current state
    # @param link_on [String] HTML ref for turning state to 'on'
    # @param link_off [String] HTML ref for turning state to 'off'
    #
    # @return [String] HTML fragment
    #
    # @example
    #   msg = toggle_text("Foobar state", true, "foobar_enable", "foobar_disable")
    #
    def toggle_text(what, state, link_on, link_off)
      format "%s: %s (<a href=\"%s\">%s</a>).",
        what,
        (state ? _("enabled") : _("disabled")),
        (state ? link_off : link_on),
        (state ? _("disable") : _("enable"))
    end

    def proposal_entry
      Yast.import "HTML"
      cio_enabled = CIOIgnore.instance.cio_enabled
      autoconf_enabled = CIOIgnore.instance.autoconf_enabled

      cio_text = toggle_text(_("Blacklist devices"), cio_enabled, CIO_ENABLE_LINK, CIO_DISABLE_LINK)
      autoconf_text = toggle_text(_("I/O device auto-configuration"), autoconf_enabled, AUTOCONF_ENABLE_LINK, AUTOCONF_DISABLE_LINK)

      {
        "preformatted_proposal" => Yast::HTML.List([cio_text, autoconf_text]),
        "links"                 => [CIO_ENABLE_LINK, CIO_DISABLE_LINK, AUTOCONF_ENABLE_LINK, AUTOCONF_DISABLE_LINK],
        # TRANSLATORS: help text
        "help"                  => _(
          "<p>Use <b>Blacklist devices</b> " \
          "if you want to create blacklist channels to such devices which will reduce kernel memory footprint.</p>" \
          "<p>Disable <b>I/O device auto-configuration</b> " \
          "if you don't want any existing I/O auto-configuration data to be applied.</p>"
        )
      }
    end

    def edit(edit_id)
      raise "Internal error: no id passed to proposal edit" unless edit_id

      log.info "CIO proposal change requested, id #{edit_id}"

      cio_ignore = CIOIgnore.instance

      case edit_id
      when CIO_DISABLE_LINK
        cio_ignore.cio_enabled = false
      when CIO_ENABLE_LINK
        cio_ignore.cio_enabled = true
      when AUTOCONF_DISABLE_LINK
        cio_ignore.autoconf_enabled = false
      when AUTOCONF_ENABLE_LINK
        cio_ignore.autoconf_enabled = true
      when ACTION_ID
        # do nothing - when there is a dialog for this, connect it here
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
    ].freeze

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
        usable = Yast::Arch.s390

        {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Blacklisting Devices..."
          ),
          "when"  => usable ? USABLE_WORKFLOWS : []
        }

      when "Write"
        write_cio_setting
        write_autoconf_setting

        nil
      else
        raise "Unknown action #{func} passed as first parameter"
      end
    end

  private

    # Update kernel options according to blacklist device setting
    #
    def write_cio_setting
      return unless CIOIgnore.instance.cio_enabled

      res = Yast::SCR.Execute(YAST_BASH_PATH, "/sbin/cio_ignore --unused --purge")

      log.info "result of cio_ignore call: #{res.inspect}"

      if res["exit"] != 0
        raise "cio_ignore command failed with stderr: #{res["stderr"]}"
      end

      # add kernel parameters that ensure that ipl and console device is never
      # blacklisted (fate#315318)
      add_cio_boot_kernel_parameters

      # store activelly used devices to not be blocked
      store_active_devices
    end

    # Update kernel options according to I/O device autoconf setting
    #
    def write_autoconf_setting
      Yast.import "Bootloader"

      if CIOIgnore.instance.autoconf_enabled
        log.info "removing rd.zdev kernel parameter"
        Yast::Bootloader.modify_kernel_params("rd.zdev" => :missing)
      else
        log.info "adding rd.zdev=no-auto kernel parameter"
        Yast::Bootloader.modify_kernel_params("rd.zdev" => "no-auto")
      end
    end

    def add_cio_boot_kernel_parameters
      Yast.import "Bootloader"

      # boot code is already proposed and will be written in next step, so just modify
      Yast::Bootloader.modify_kernel_params("cio_ignore" => "all,!ipldev,!condev")
    end

    ACTIVE_DEVICES_FILE = "/boot/zipl/active_devices.txt".freeze
    def store_active_devices
      Yast.import "Installation"
      res = Yast::SCR.Execute(YAST_BASH_PATH, "/sbin/cio_ignore -L")
      log.info "active devices: #{res}"

      raise "cio_ignore -L failed with #{res["stderr"]}" if res["exit"] != 0
      # lets select only lines that looks like device. Regexp is not perfect, but good enough
      devices_lines = res["stdout"].lines.grep(/^(?:\h.){0,2}\h{4}.*$/)

      devices = devices_lines.map(&:chomp)
      target_file = File.join(Yast::Installation.destdir, ACTIVE_DEVICES_FILE)

      # make sure the file ends with a new line character
      devices << "" unless devices.empty?

      File.write(target_file, devices.join("\n"))
    end
  end
end

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

    def run(args)
      func = args.first
      param = args[1] || {}

      log.debug "cio ignore client called with #{func} and #{param}"

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
      enabled = CIOIgnore.instance.enabled
      text = "<ul><li>\n"

      if enabled
        # TRANSLATORS: Installation overview
        # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
        text << (_(
            "Blacklist devices enabled (<a href=\"%s\">disable</a>)."
          ) % CIO_DISABLE_LINK)
      else
        # TRANSLATORS: Installation overview
        # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
        text << (_(
            "Blacklist devices disabled (<a href=\"%1\">enable</a>)."
          ) % CIO_ENABLE_LINK)
      end

      text << "</li></ul>\n"

      {
        "preformatted_proposal" => text,
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
            raise "Unexpected value #{edit_id}"
          end

        { "workflow_sequence" => :next }
    end
  end
end

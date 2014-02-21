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

      case func
      when "MakeProposal"
        proposal_entry
      else
        raise "uknown method"
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
  end
end

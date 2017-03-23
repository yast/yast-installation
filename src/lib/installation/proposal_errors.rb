require "yast"

Yast.import "UI"
Yast.import "Label"
Yast.import "Mode"
Yast.import "Popup"

module Installation
  class ProposalErrors
    include Yast::I18n
    include Yast::Logger

    ERROR_PROPOSAL_TIMEOUT = 60

    def initialize
      textdomain "installation"
      @errors = []
    end

    # clears previously stored errros
    def clear
      @errors = []
    end

    # appends new error with given message
    def append(message)
      @errors << message
    end

    # returns true if there is no error or user approved stored errors
    def approved?
      return true if @errors.empty?

      headline = _("Error Found in Installation Settings")
      text = _("The following errors were found in the configuration proposal.\n" \
        "If you continue with the installation it may not be successful.\n" \
        "Errors:\n")
      sep = Yast::UI.TextMode ? "-" : "•"
      text += "#{sep} " + @errors.join("\n#{sep} ")

      if Yast::Mode.auto
        !Yast::Popup.TimedErrorAnyQuestion(headline, text,
          Yast::Label.BackButton, Yast::Label.ContinueButton, :focus_yes,
          ERROR_PROPOSAL_TIMEOUT)
      else
        !Yast::Popup.ErrorAnyQuestion(headline, text,
          Yast::Label.BackButton, Yast::Label.ContinueButton, :focus_yes)
      end
    end
  end
end

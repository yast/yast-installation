require "yast"
require "network/install_inf_convertor"
require "installation/dialogs/registration_url_dialog"

module Yast
  class InstInstallInfClient < Client
    VALID_URL_SCHEMES = ["http", "https"].freeze

    include Yast::Logger
    include Yast::I18n

    Yast.import "Linuxrc"
    Yast.import "Wizard"
    Yast.import "WFM"

    def main
      textdomain "installation"

      InstallInfConvertor.instance.write_netconfig unless Mode.auto

      Yast::Wizard.CreateDialog if separate_wizard_needed?

      regurl = Linuxrc.InstallInf("regurl")

      fix_regurl!(regurl) if need_fix?(regurl)

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      :next
    end

  private

    # Checks if the given url is invalid and needs to be fixed.
    #
    # @param url [String]
    # @return [Boolean] return true if not nil and invalid.
    def need_fix?(url)
      url && !valid_url?(url)
    end

    # Shows a dialog allowing the user to modify the invalid URL, modifying the
    # /etc/install.inf file with the new value. In case of cancelled or empty,
    # the URL will be completely removed.
    #
    # @param regurl [String]
    def fix_regurl!(regurl)
      while need_fix?(regurl)
        new_url = ::Installation::RegistrationURLDialog.new(regurl).run
        case new_url
        when :cancel
          if Popup.YesNo(_("If you decide to cancel, the custom URL\n" \
                         "will be completelly ignored.\n\n" \
                         "Really cancel URL modification?"))
            regurl = nil
          end
        when "",
          regurl = nil
        else
          regurl = new_url
        end
      end

      SCR.Write(path(".etc.install_inf.regurl"), regurl)
      SCR.Write(path(".etc.install_inf"), nil) # Flush the cache
      Linuxrc.ResetInstallInf
    end

    # Check if the given URI is valid or not
    #
    # @param url [String]
    # @return [Boolean]
    def valid_url?(url)
      VALID_URL_SCHEMES.include?(URI(url).scheme)
    rescue URI::InvalidURIError
      false
    end

    # Returns whether we need/ed to create new UI Wizard
    def separate_wizard_needed?
      Yast::Mode.normal
    end
  end
end

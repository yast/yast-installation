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

      if need_fix?(regurl)
        fix_regurl!(regurl)
        Linuxrc.ResetInstallInf
      end

      Yast::Wizard.CloseDialog if separate_wizard_needed?

      :next
    end

  private

    def need_fix?(url)
      url && !valid_url?(url)
    end

    def fix_regurl!(regurl)
      while regurl && !valid_url?(regurl)
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

      regurl ? replace_install_inf("regurl", regurl) : delete_install_inf("regurl")
    end

    # Check if the given URI is valid or not
    #
    # @params url [String]
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

    def replace_install_inf(key, value)
      # Updating new URI in /etc/install.inf (bnc#963487)
      # SCR.Write does not work in inst-sys here.
      WFM.Execute(
        path(".local.bash"),
        "sed -i \'/#{key}:/c\\#{key}: #{value}\' /etc/install.inf"
      )
    end

    def delete_install_inf(key)
      # Deleting URI in /etc/install.inf (bnc#963487)
      # SCR.Write does not work in inst-sys here.
      WFM.Execute(
        path(".local.bash"),
        "sed -i \'/#{key}:/d\' /etc/install.inf"
      )
    end
  end
end

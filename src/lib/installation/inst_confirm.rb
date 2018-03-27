require "yast"

Yast.import "Installation"
Yast.import "Mode"
Yast.import "ProductControl"
Yast.import "Storage"
Yast.import "Label"
Yast.import "CWM"
Yast.import "HTML"
Yast.import "GetInstArgs"
Yast.import "InstData"
Yast.import "ProductLicense"

module Yast
   
  class InstConfirmDialog

    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      # Confirm installation or update.
      # Returns 'true' if the user confirms, 'false' otherwise.
      #
      textdomain "installation"
      confirm_license = true

      heading = ""
      body = ""
      confirm_button_label = ""

      @license_id = Ops.get(Pkg.SourceGetCurrent(true), 0, 0)
      log.info ("License ID of base product: #{@license_id}")

      if !Mode.update
        # Heading for confirmation popup before the installation really starts
        heading = HTML.Heading(_("Confirm Installation"))

        # Text for confirmation popup before the installation really starts 1/3
        body = _(
          "<p>Information required for the base installation is now complete.</p>"
        )

        some_destructive = Storage.GetCommitInfos.any? do |info|
          Ops.get_boolean(info, :destructive, false)
        end

        if some_destructive
          # Text for confirmation popup before the installation really starts 2/3
          body = Ops.add(
            body,
            _(
              "<p>If you continue now, <b>existing\n" \
                "partitions</b> on your hard disk will be <b>deleted</b> or <b>formatted</b>\n" \
                "(<b>erasing any existing data</b> in those partitions) according to the\n" \
                "installation settings in the previous dialogs.</p>"
            )
          )
        else
          # Text for confirmation popup before the installation really starts 2/3
          body = Ops.add(
            body,
            _(
              "<p>If you continue now, partitions on your\n" \
                "hard disk will be modified according to the installation settings in the\n" \
                "previous dialogs.</p>"
            )
          )
        end

        # Text for confirmation popup before the installation really starts 3/3
        body = Ops.add(
          body,
          _("<p>Go back and check the settings if you are unsure.</p>")
        )

        confirm_button_label = Label.InstallButton
      else
        # Heading for confirmation popup before the update really starts
        heading = HTML.Heading(_("Confirm Update"))

        body =
          # Text for confirmation popup before the update really starts 1/3
          _("<p>Information required to perform an update is now complete.</p>") +
          # Text for confirmation popup before the update really starts 2/3
          _(
            "\n" \
              "<p>If you continue now, data on your hard disk will be overwritten\n" \
              "according to the settings in the previous dialogs.</p>"
          ) +
          # Text for confirmation popup before the update really starts 3/3
          _("<p>Go back and check the settings if you are unsure.</p>")

        # Label for the button that confirms startint the installation
        confirm_button_label = _("Start &Update")
      end
   
      if confirm_license
        widgets = layout_with_license(heading, body, confirm_button_label)
      else
        widgets = layout_without_license(heading, body, confirm_button_label)
      end

      UI.OpenDialog(
        widgets
      )

      initialize_license if confirm_license

      button = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog

      button == :ok
    end

private
  
    def layout_without_license(heading, body, confirm_button_label)
      display_info = UI.GetDisplayInfo
      size_x = Builtins.tointeger(Ops.get_integer(display_info, "Width", 800))
      size_y = Builtins.tointeger(Ops.get_integer(display_info, "Height", 600))

      # 576x384 support for for ps3
      # bugzilla #273147
      if Ops.greater_or_equal(size_x, 800) && Ops.greater_or_equal(size_y, 600)
        size_x = 70
        size_y = 18
      else
        size_x = 54
        size_y = 15
      end

      VBox(
        VSpacing(0.4),
        HSpacing(size_x), # force width
        HBox(
          HSpacing(0.7),
          VSpacing(size_y), # force height
          RichText(heading + body),
          HSpacing(0.7)
        ),
        ButtonBox(
          PushButton(
            Id(:cancel),
            Opt(:cancelButton, :key_F10, :default),
            Label.BackButton
          ),
          PushButton(Id(:ok), Opt(:okButton, :key_F9), confirm_button_label)
        )
      )
    end

    def layout_with_license(heading, body, confirm_button_label)
      VBox(
        VWeight(10,
          HBox(
            HSpacing(0.7),
            RichText(heading + body),
            HSpacing(0.7)
          )
        ),
        VWeight(
          30,
          Left(
            HSquash(
              HBox(
                HSpacing(0.7),
                VBox(
                  HBox(
                    Left(Label(Opt(:boldFont), _("License Agreement"))),
                    HStretch()
                  ),
                  # bnc #438100
                  HSquash(
                    MinWidth(
                      # BNC #607135
                      text_mode? ? 85 : 106,
                      Left(ReplacePoint(Id(:base_license_rp), Opt(:hstretch), Empty()))
                    )
                  ),
                  VSpacing(text_mode? ? 0.1 : 0.5),
                  MinHeight(
                    1,
                    # Will be replaced with license checkbox if required
                    ReplacePoint(Id(:license_checkbox_rp), Empty())
                  )
                ),
                HSpacing(0.7)
              )
            )
          )
        ),
        VWeight(3,
          ButtonBox(
            PushButton(
              Id(:cancel),
              Opt(:cancelButton, :key_F10, :default),
              Label.BackButton
            ),
            PushButton(Id(:ok), Opt(:okButton, :key_F9), confirm_button_label)
          ))
      )
    end


    def text_mode?
      return @text_mode unless @text_mode.nil?

      @text_mode = UI.TextMode
    end

    # Determines whether the license is required or not
    #
    # @return [Boolean] true if license is required; false otherwise.
    def license_required?
      return @license_required unless @license_required.nil?
      @license_required = ProductLicense.AcceptanceNeeded(@license_id.to_s)
    end

    # Report error about missing license acceptance
    def warn_license_required
      UI.SetFocus(Id(:license_agreement))
      Report.Message(_("You must accept the license to install this product"))
    end

    # License sometimes doesn't need to be manually accepted
    def license_agreement_checkbox
      Left(
        CheckBox(
          # bnc #359456
          Id(:license_agreement),
          Opt(:notify),
          # TRANSLATORS: check-box
          _("I &Agree to the License Terms."),
          InstData.product_license_accepted
        )
      )
    end

    def initialize_license
      # If accepting the license is required, show the check-box
      if license_required?
        UI.ReplaceWidget(:license_checkbox_rp, license_agreement_checkbox)
        UI.ChangeWidget(Id(:license_agreement), :Value, InstData.product_license_accepted)
      end

      log.info "Acceptance needed: #{@id} => #{license_required?}"

      # The info file has already been seen in inst_casp_overview before.
      ProductLicense.info_seen!(@license_id)
      ProductLicense.ShowLicenseInInstallation(:base_license_rp, @license_id)
    end


  end

end

# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "cgi"
require "yast"
require "ui/installation_dialog"
require "installation/services"
require "installation/system_role"
require "ui/text_helpers"

Yast.import "GetInstArgs"
Yast.import "Packages"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  class SelectSystemRole < ::UI::InstallationDialog
    include UI::TextHelpers

    NON_OVERLAY_ATTRIBUTES = [
      "additional_dialogs",
      "id",
      "services"
    ].freeze

    def initialize
      super

      textdomain "installation"
    end

    def run
      if roles(refresh: true).empty?
        log.info "No roles defined, skipping their dialog"
        return :auto # skip forward or backward
      end

      if Yast::GetInstArgs.going_back
        # If coming back, we have to run the additional dialogs first...
        clients = additional_clients_for(SystemRole.current)
        direction = run_clients(clients, going_back: true)
        # ...and only run the main dialog (super) if there is more than one role (fate#324713)
        # and we are *still* going back
        return direction if single_role? || direction != :back
      end

      if single_role?
        # Apply the role and skip the dialog when there is only one (fate#324713)
        log.info "Only one role available, applying it and skipping the dialog"
        clear_role
        return select_role(roles.first.id)
      end

      super
    end

    def dialog_title
      Yast::ProductControl.GetTranslatedText("roles_caption")
    end

    def help_text
      Yast::ProductControl.GetTranslatedText("roles_help")
    end

    def dialog_content
      @selected_role_id = SystemRole.current
      @selected_role_id ||= roles.first&.id if SystemRole.default?

      HCenter(ReplacePoint(Id(:rp), role_buttons(selected_role_id: @selected_role_id)))
    end

    def create_dialog
      clear_role
      ok = super
      Yast::UI.SetFocus(Id(:roles_richtext)) if ok
      ok
    end

    def next_handler
      result = select_role(@selected_role_id)
      # We show the main role dialog; but the additional clients have
      # drawn over it, so draw it again and go back to input loop.
      # create_dialog do not create new dialog if it already exist like in this
      # case.
      if result == :back
        create_dialog
        return
      else
        finish_dialog(result)
      end
    end

    # called if a specific FOO_handler is not defined
    def handle_event(id)
      role = SystemRole.find(id)
      if role.nil?
        log.info "Not a role: #{id.inspect}, skipping"
        return
      end

      @selected_role_id = id
      Yast::UI.ReplaceWidget(Id(:rp), role_buttons(selected_role_id: id))
      Yast::UI.SetFocus(Id(:roles_richtext))
    end

  private

    # checks if there is only one role available
    def single_role?
      roles.size == 1
    end

    # Applies the role with given id and run its additional clients, if any
    #
    # @param role_id [Integer] The role to be applied
    #
    # @see run_clients
    #
    # @return [:next,:back,:abort] which direction the additional dialogs exited
    def select_role(role_id)
      if role_id.nil?
        # no role selected (bsc#1078809)
        Yast::Popup.Error(_("Select one of the available roles to continue."))
        return :back
      end

      if SystemRole.current && SystemRole.current != role_id
        # Changing the role, show a Continue-Cancel popup to user
        msg = _("Changing the system role may undo adjustments you may have done.")
        return :back unless Yast::Popup.ContinueCancel(msg)
      end

      apply_role(role_id)
      run_clients(additional_clients_for(role_id))
    end

    # gets array of clients to run for given role
    def additional_clients_for(role_id)
      role = SystemRole.find(role_id)
      clients = role["additional_dialogs"] || ""
      clients.split(",").map!(&:strip)
    end

    # @note it is a bit specialized form of {ProductControl.RunFrom}
    # @param clients [Array<String>] list of clients to run. Requirement is to
    #   work well with installation wizard. Suggestion is to use
    #   {InstallationDialog} as base.
    # @param going_back [Boolean] when going in reverse order of clients
    # @return [:next,:back,:abort] which direction the additional dialogs exited
    def run_clients(clients, going_back: false)
      result = going_back ? :back : :next
      return result if clients.empty?

      client_to_show = going_back ? clients.size - 1 : 0
      loop do
        result = Yast::WFM.CallFunction(clients[client_to_show],
          [{
            "going_back"  => going_back,
            "enable_next" => true,
            "enable_back" => true
          }])

        log.info "client #{clients[client_to_show]} return #{result}"

        step = case result
        when :auto
          going_back ? -1 : +1
        when :next
          +1
        when :back
          -1
        when :abort
          return :abort
        else
          raise "unsupported client response #{result.inspect}"
        end

        client_to_show += step
        break unless (0..(clients.size - 1)).cover?(client_to_show)
      end

      (client_to_show >= clients.size) ? :next : :back
    end

    def clear_role
      Yast::ProductFeatures.ClearOverlay
    end

    # Applies given role to configuration
    def apply_role(role_id)
      log.info "Applying system role '#{role_id}'"

      role = SystemRole.select(role_id)
      role.overlay_features
      adapt_services(role)

      select_packages
    end

    # Selects packages for the currently selected role
    #
    # Note that everything that was previously selected by the solver needs to be reset.
    # Otherwise, the solver would not select the same list of patterns when the same role
    # is selected again (bsc#1126517).
    #
    # Moreover, all patterns should be reset because many roles define their own roles, so
    # the new patterns need to be properly set when going back (bsc#1088883). Only patterns
    # selected by the user should be kept.
    def select_packages
      # By default, Packages.Reset resets a resolvable if the resolvable was not explicitly
      # selected by the user. When a resolvable type is given in the parameter list, those
      # resolvables are only reset when they were automatically selected by the solver.
      #
      # Products, patches, packages and languages are only reset if they were automatically
      # selected by the solver. However, patterns are only kept if they were selected by the
      # user (note that :pattern is not included in the Reset param list).
      Yast::Packages.Reset([:product, :patch, :package, :language])

      Yast::Packages.SelectSystemPatterns(false)
      Yast::Packages.SelectSystemPackages(false)

      Yast::Pkg.PkgSolve(false)
    end

    # for given role sets in {::Installation::Services} list of services to enable
    # according to its config. Do not use alone and use apply_role instead.
    def adapt_services(role)
      services = role["services"] || []

      to_enable = services.map { |s| s["name"] }
      log.info "enable for #{role.id} these services: #{to_enable.inspect}"

      Installation::Services.enabled = to_enable
    end

    # Return the list of defined roles
    #
    # @param [Boolean] refresh Refresh system roles cache
    # @return [Array<SystemRole>] List of defined roles
    #
    # @see SystemRole.all
    # @see SystemRole.clear
    def roles(refresh: false)
      # Refresh system roles list
      SystemRole.clear if refresh
      SystemRole.all
    end

    # Returns the content for the role buttons
    # @param selected_role_id [String] which role radiobutton gets selected
    # @return [Yast::Term] Role buttons
    def role_buttons(selected_role_id:)
      role_rt_radios = roles.map do |role|
        # FIXME: following workaround can be removed as soon as bsc#997402 is fixed:
        # bsc#995082: System role descriptions use a character that is missing in console font
        description = Yast::UI.TextMode ? role.description.tr("•", "*") : role.description

        rb = richtext_radiobutton(id:       role.id,
                                  label:    role.label,
                                  selected: role.id == selected_role_id)

        description = CGI.escape_html(description).gsub("\n", "<br>\n")
        # extra empty paragraphs for better spacing
        "<p></p>#{rb}<p></p><ul>#{description}</ul>"
      end

      intro_text = Yast::ProductControl.GetTranslatedText("roles_text")
      VBox(
        Left(Label(intro_text)),
        VSpacing(2),
        RichText(Id(:roles_richtext), div_with_direction(role_rt_radios.join("\n")))
      )
    end

    def richtext_radiobutton(id:, label:, selected:)
      if Yast::UI.TextMode
        richtext_radiobutton_tui(id: id, label: label, selected: selected)
      else
        richtext_radiobutton_gui(id: id, label: label, selected: selected)
      end
    end

    def richtext_radiobutton_tui(id:, label:, selected:)
      check = selected ? "(x)" : "( )"
      widget = "#{check} #{CGI.escape_html(label)}"
      enabled_widget = "<a href=\"#{id}\">#{widget}</a>"
      "#{enabled_widget}<br>"
    end

    IMAGE_DIR = "/usr/share/YaST2/theme/current/wizard".freeze

    BUTTON_ON = "◉".freeze # U+25C9 Fisheye
    BUTTON_OFF = "○".freeze # U+25CB White Circle

    def richtext_radiobutton_gui(id:, label:, selected:)
      # check for installation style, which is dark, FIXME: find better way
      installation = ENV["Y2STYLE"] == "installation.qss"
      if installation
        image = selected ? "inst_radio-button-checked.png" : "inst_radio-button-unchecked.png"
        # NOTE: due to a Qt bug, the first image does not get rendered properly. So we are
        # rendering it twice (one with height and width set to "0").
        bullet = "<img src=\"#{IMAGE_DIR}/#{image}\" height=\"0\" width=\"0\"></img>" \
                 "<img src=\"#{IMAGE_DIR}/#{image}\"></img>"
      else
        bullet = selected ? BUTTON_ON : BUTTON_OFF
      end
      widget = "#{bullet} #{CGI.escape_html(label)}"
      enabled_widget = "<a class='dontlooklikealink' href=\"#{id}\">#{widget}</a>"
      "<p>#{enabled_widget}</p>"
    end
  end
end

# coding: utf-8
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

Yast.import "GetInstArgs"
Yast.import "Packages"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  class SelectSystemRole < ::UI::InstallationDialog
    class << self
      # once the user selects a role, remember it in case they come back
      attr_accessor :original_role_id
    end

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
        clients = additional_clients_for(self.class.original_role_id)
        direction = run_clients(clients, going_back: true)
        # ... and only run the main dialog (super) if we are *still* going back
        return direction unless direction == :back
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
      @selected_role_id = self.class.original_role_id
      @selected_role_id ||= roles.first && roles.first.id if SystemRole.default?

      HCenter(ReplacePoint(Id(:rp), role_buttons(selected_role_id: @selected_role_id)))
    end

    def create_dialog
      clear_role
      ok = super
      Yast::UI.SetFocus(Id(:roles_richtext)) if ok
      ok
    end

    def next_handler
      role_id = @selected_role_id

      if role_id.nil? # no role selected (bsc#1078809)
        # An Error popup
        msg = _("Select one of the available roles to continue.")
        Yast::Popup.Error(msg)
        return
      end

      orig_role_id = self.class.original_role_id
      if !orig_role_id.nil? && orig_role_id != role_id
        # A Continue-Cancel popup
        msg = _("Changing the system role may undo adjustments you may have done.")
        return unless Yast::Popup.ContinueCancel(msg)
      end
      self.class.original_role_id = role_id

      apply_role(SystemRole.find(role_id))

      result = run_clients(additional_clients_for(role_id))
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

      client_to_show >= clients.size ? :next : :back
    end

    def clear_role
      Yast::ProductFeatures.ClearOverlay
    end

    # Applies given role to configuration
    def apply_role(role)
      log.info "Applying system role '#{role.id}'"
      role.overlay_features
      adapt_services(role)

      # Reset pkg and pattern selection as many roles define own roles
      # so ensure when going back that it will properly set (bsc#1088883)
      Yast::Pkg.PkgApplReset
      Yast::Packages.SelectSystemPatterns(false)
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
        RichText(Id(:roles_richtext), role_rt_radios.join("\n"))
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
        bullet = "<img src=\"#{IMAGE_DIR}/#{image}\"></img>"
      else
        bullet = selected ? BUTTON_ON : BUTTON_OFF
      end
      widget = "#{bullet} #{CGI.escape_html(label)}"
      color = installation ? "white" : "black"
      enabled_widget = "<a style='text-decoration:none; color:#{color}' href=\"#{id}\">#{widget}</a>"
      "<p>#{enabled_widget}</p>"
    end
  end
end

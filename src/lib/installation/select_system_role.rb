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

require "yast"
require "ui/installation_dialog"
require "installation/services"
require "installation/system_role"

Yast.import "GetInstArgs"
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
      HSquash(VBox(role_buttons))
    end

    def create_dialog
      clear_role
      ok = super
      role_id = self.class.original_role_id || (roles.first && roles.first.id)
      Yast::UI.ChangeWidget(Id(:roles), :CurrentButton, role_id)
      ok
    end

    def next_handler
      role_id = Yast::UI.QueryWidget(Id(:roles), :CurrentButton)

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

    # Returns the content for the role buttons
    #
    # @return [Yast::Term] Role buttons
    #
    # @see role_buttons_options
    def role_buttons
      role_buttons_content(role_buttons_options)
    end

    # Applies given role to configuration
    def apply_role(role)
      log.info "Applying system role '#{role.id}'"
      role.overlay_features
      adapt_services(role)
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

    # Returns the content for the role buttons according to the available space
    #
    # @param separation  [Integer] Separation between roles
    # @param indentation [Integer] Roles indentation
    # @param margin      [Integer] Top marging
    # @param description [Boolean] Indicates whether the description should be included
    # @return [Yast::Term] Role buttons
    def role_buttons_content(margin: 2, indentation: 4, separation: 2, description: true, show_intro: true)
      box = []
      box << Left(Label(Yast::ProductControl.GetTranslatedText("roles_text"))) if show_intro
      box << VSpacing(margin) unless margin.zero?

      ui_roles = roles.each_with_object(box) do |role, vbox|
        # FIXME: following workaround can be removed as soon as bsc#997402 is fixed:
        # bsc#995082: System role descriptions use a character that is missing in console font
        role_description = Yast::UI.TextMode ? role.description.tr("•", "*") : role.description
        vbox << Left(RadioButton(Id(role.id), role.label))
        vbox << HBox(HSpacing(indentation), Left(Label(role_description))) if description
        vbox << VSpacing(separation) unless roles.last == role || separation.zero?
      end

      RadioButtonGroup(Id(:roles), VBox(*ui_roles))
    end

    # Default role buttons options for the Qt UI
    DEFAULT_ROLE_BUTTONS_QT_OPTS = {
      indentation: 4,
      margin:      2,
      separation:  2,
      show_intro:  true,
      description: true
    }.freeze

    # Default role buttons options for the textmode UI
    DEFAULT_ROLE_BUTTONS_TEXT_OPTS = {
      indentation: 2,
      margin:      1,
      separation:  2,
      show_intro:  true,
      description: true
    }.freeze

    def intro_text
      @intro_text ||= Yast::ProductControl.GetTranslatedText("roles_text")
    end

    # Space for roles
    #
    # @return [Hash] Options to distribute roles
    #
    # @see available_lines_for_roles
    def role_buttons_options
      return DEFAULT_ROLE_BUTTONS_QT_OPTS unless Yast::UI.TextMode

      opts = textmode_role_buttons_options
      log.info "Options for role buttons: #{opts.inspect}"
      opts
    end

    # Returns space options for roles in textmode
    #
    # @return [Hash] Options to distribute roles
    def textmode_role_buttons_options
      opts = DEFAULT_ROLE_BUTTONS_TEXT_OPTS.dup

      # Set separation
      separation = [
        DEFAULT_ROLE_BUTTONS_TEXT_OPTS[:separation],
        (available_lines_for_roles - needed_lines_for_roles - opts[:margin]) / 2
      ].min
      separation = 0 if separation < 0
      opts = DEFAULT_ROLE_BUTTONS_TEXT_OPTS.merge(separation: separation)

      # Set intro size
      intro_lines = intro_text.lines.size

      # No space for descriptions
      opts[:description] = false if needed_lines_for_roles > available_lines_for_roles

      # No space for margin
      opts[:margin] = 0 if roles.size + intro_lines + opts[:margin] > available_lines_for_roles

      # No space for intro
      opts[:show_intro] = false if roles.size + intro_lines > available_lines_for_roles

      opts
    end

    # Number of required lines to show roles information and buttons
    #
    # Title + Descriptions
    #
    # @return [Integer] Number of lines needed to display roles information
    def needed_lines_for_roles
      return @needed_lines_for_roles if @needed_lines_for_roles
      texts = roles.map(&:description)
      texts << intro_text unless intro_text.nil?
      lines_qty = texts.compact.map(&:lines).map(&:size).reduce(:+)
      @needed_lines_for_roles = roles.size + lines_qty
    end

    # Space taken by header/footer and not available for the roles buttons
    RESERVED_LINES = 4
    # Returns an estimation of the available space for displaying the roles buttons
    #
    # @return [Integer] Estimated amount of available space
    def available_lines_for_roles
      @available_lines_for_roles ||= Yast::UI.GetDisplayInfo()["Height"] - RESERVED_LINES
    end
  end
end

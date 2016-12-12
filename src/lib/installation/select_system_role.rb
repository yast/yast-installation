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

Yast.import "GetInstArgs"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  # marker exception when additional dialog return abort
  class AbortException < RuntimeError; end

  class SelectSystemRole < ::UI::InstallationDialog
    class << self
      # once the user selects a role, remember it in case they come back
      attr_accessor :original_role_id
    end

    NON_OVERLAY_ATTRIBUTES = [
      "additional_dialogs",
      "id"
    ].freeze

    def initialize
      super

      textdomain "installation"
    end

    def run
      if raw_roles.empty?
        log.info "No roles defined, skipping their dialog"
        return :auto # skip forward or backward
      end

      if Yast::GetInstArgs.going_back
        return :next if run_clients(self.class.original_role_id, going_back: true)
      end

      super
    rescue AbortException
      return :abort
    end

    def dialog_title
      Yast::ProductControl.GetTranslatedText("roles_caption")
    end

    def help_text
      Yast::ProductControl.GetTranslatedText("roles_help")
    end

    def dialog_content
      HSquash(
        VBox(
          Left(Label(Yast::ProductControl.GetTranslatedText("roles_text"))),
          VSpacing(2),
          role_buttons
        )
      )
    end

    def create_dialog
      clear_role
      ok = super
      role_id = self.class.original_role_id || role_attributes.first[:id]
      Yast::UI.ChangeWidget(Id(:roles), :CurrentButton, role_id)
      ok
    end

    def next_handler
      role_id = Yast::UI.QueryWidget(Id(:roles), :CurrentButton)

      orig_role_id = self.class.original_role_id
      if !orig_role_id.nil? && orig_role_id != role_id
        # A Continue-Cancel popup
        msg = _("Changing the system role may undo adjustments you may have done.")
        return unless Yast::Popup.ContinueCancel(msg)
      end
      self.class.original_role_id = role_id

      apply_role(role_id)

      # if run clients goes back, then show again this dialog
      if !run_clients(role_id)
        # We show the main role dialog; but the additional clients have
        # drawn over it, so do it again, and propagate its result.
        finish_dialog(run)
        return
      end

      super

    rescue AbortException
      finish_dialog(:abort)
      return
    end

  private

    # @return true if clients successfully go to next dialog after roles
    def run_clients(role_id, going_back: false)
      clients = raw_roles.find { |r| r["id"] == role_id }["additional_dialogs"]
      clients ||= ""
      clients = clients.split(",").map!(&:strip)

      return !going_back if clients.empty?
      result = going_back ? :back : :next

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
          raise AbortException, "client aborted"
        else
          raise "unsupported client response #{result.inspect}"
        end

        client_to_show += step
        break unless (0..(clients.size - 1)).cover?(client_to_show)
      end

      client_to_show >= clients.size
    end

    def clear_role
      Yast::ProductFeatures.ClearOverlay
    end

    def role_buttons
      ui_roles = role_attributes.each_with_object(VBox()) do |r, vbox|
        # bsc#995082: System role descriptions use a character that is missing in console font
        description = Yast::UI.TextMode ? r[:description].tr("•", "*") : r[:description]
        vbox << Left(RadioButton(Id(r[:id]), r[:label]))
        vbox << HBox(
          HSpacing(Yast::UI.TextMode ? 4 : 2),
          Left(Label(description))
        )
        vbox << VSpacing(2)
      end

      RadioButtonGroup(Id(:roles), ui_roles)
    end

    def apply_role(role_id)
      log.info "Applying system role '#{role_id}'"
      features = raw_roles.find { |r| r["id"] == role_id }
      features = features.dup
      NON_OVERLAY_ATTRIBUTES.each { |a| features.delete(a) }
      Yast::ProductFeatures.SetOverlay(features)
    end

    # the contents is an overlay for ProductFeatures sections
    # [
    #  { "id" => "foo", "partitioning" => ... },
    #  { "id" => "bar", "partitioning" => ... , "software" => ...},
    # ]
    # @return [Array<Hash{String => Object}>]
    def raw_roles
      Yast::ProductControl.productControl.fetch("system_roles", [])
    end

    def role_attributes
      raw_roles.map do |r|
        id = r["id"]

        {
          id:          id,
          label:       Yast::ProductControl.GetTranslatedText(id),
          description: Yast::ProductControl.GetTranslatedText(id + "_description")
        }
      end
    end
  end
end

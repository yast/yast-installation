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
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "ProductFeatures"

module Installation
  class SelectSystemRole < ::UI::InstallationDialog
    class << self
      # once the user selects a role, remember it in case they come back
      attr_accessor :original_role_id
    end

    def initialize
      super

      textdomain "installation"
    end

    def run
      if raw_roles.empty?
        log.info "No roles defined, skipping their dialog"
        return :auto            # skip forward or backward
      end

      super
    end

    def dialog_title
      _("System Role")
    end

    def help_text
      ""                    # no Help, besides the descriptions in dialog body
    end

    def dialog_content
      ui_roles = role_attributes.each_with_object(VBox()) do |r, vbox|
        vbox << Left(RadioButton(Id(r[:id]), r[:label]))
        vbox << HBox(
          HSpacing(Yast::UI.TextMode ? 4 : 2),
          Left(Label(r[:description]))
        )
        vbox << VSpacing(2)
      end

      RadioButtonGroup(Id(:roles), ui_roles)
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
        Yast::Popup.ContinueCancel(msg) || return
      end
      self.class.original_role_id = role_id

      apply_role(role_id)

      super
    end

  private

    def clear_role
      Yast::ProductFeatures.ClearOverlay
    end

    def apply_role(role_id)
      log.info "Applying system role '#{role_id}'"
      features = raw_roles.find { |r| r["id"] == role_id }
      features = features.dup
      features.delete("id")
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

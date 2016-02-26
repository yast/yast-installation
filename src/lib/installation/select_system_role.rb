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

module Installation
  class SelectSystemRole < ::UI::InstallationDialog
    include Yast

    def initialize
      super

      textdomain "installation"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
    end

    def run
      if raw_roles.empty?
        log.info "No roles defined, skipping their dialog"
        return :auto            # skip forward or backward
      end

      super
    end

    public                      # called by parent class

    def dialog_title
      _("System Role")
    end

    def help_text
      ""                    # no Help, besides the descriptions in dialog body
    end

    def dialog_content
      RadioButtonGroup(
        Id(:roles),
        VBox(
          * ui_roles.map do |r|
              VBox(
                Left(RadioButton(Id(r[:id]), r[:label])),
                HBox(
                  HSpacing(4),
                  Left(Label(r[:description]))
                ),
                VSpacing(2)
              )
            end
        )
      )
    end

    def create_dialog
      clear_role
      ok = super
      UI.ChangeWidget(Id(:roles), :CurrentButton, ui_roles.first[:id])
      ok
    end

    def next_handler
      role_id = UI.QueryWidget(Id(:roles), :CurrentButton)
      apply_role(role_id)

      super
    end

    private

    def clear_role
      ProductFeatures.ClearOverlay
    end

    def apply_role(role_id)
      log.info "Applying system role '#{role_id}'"
      features = raw_roles.find { |r| r["id"] == role_id }
      features = features.dup
      features.delete("id")
      ProductFeatures.SetOverlay(features)
    end

    # the contents is an overlay for ProductFeatures sections
    # [
    #  { "id" => "foo", "partitioning" => ... },
    #  { "id" => "bar", "partitioning" => ... , "software" => ...},
    # ]
    # @return [Array<Hash{String => Object}>]
    def raw_roles
      ProductControl.productControl.fetch("system_roles", [])
    end

    def ui_roles
      raw_roles.map do |r|
        id = r["id"]

        {
          id:          id,
          label:       ProductControl.GetTranslatedText(id),
          description: ProductControl.GetTranslatedText(id + "_description")
        }
      end
    end
  end
end

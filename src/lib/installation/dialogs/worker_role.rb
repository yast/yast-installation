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

require "ui/installation_dialog"

module Yast
  class WorkerRoleDialog < ::UI::InstallationDialog
    def initialize
      super

      textdomain "installation"
    end

    def next_handler
      # TODO: Add the registration process

      log.error("Worker role dialog should register with the admin dashboard")

      super
    end

  private

    def dialog_content
      HSquash(
        VBox(
          Heading("Register this worker in the admin dashboard"),
          VSpacing(1),
          VBox(
            InputField(Id(:dashboard_url), Opt(:hstretch), _("Dashboard U&RL"))
          )
        )
      )
    end

    def dialog_title
      _("Worker Registration")
    end

    def help_text
      # FIXME: This client is a POC and still under definition

      _("Enter the url of the admin dashboard to register as a worker")
    end
  end
end

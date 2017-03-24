# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"

module Installation
  # Run system roles handlers
  #
  # System role handlers are a mechanism to execute code depending on the
  # selected role. Currently those handlers are only used in the inst_finish
  # client, but they could be extended in the future.
  class SystemRoleHandlersRunner
    include Yast::Logger

    # Run the finish handler for a given role
    def finish(role_id)
      return unless require_handler(role_id)

      class_name_role = role_id.split("_").map(&:capitalize).join
      handler = "Y2SystemRoleHandlers::#{class_name_role}Finish"

      if Object.const_defined?(handler)
        Object.const_get(handler).new.run
      else
        log.info("There is no special finisher for #{role_id} ('#{class_name_role}' not defined)")
      end
    end

  private

    # Try to require the file where a handler is supposed to be defined
    #
    # @return [Boolean] True if the file was loaded; false otherwise.
    def require_handler(role_id)
      filename = "y2system_role_handlers/#{role_id}_finish"
      require filename
      true
    rescue LoadError
      log.info("There is no special finisher for #{role_id} ('#{filename}' not found)")
    end
  end
end

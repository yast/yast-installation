# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"
require "cwm/custom_widget"
require "cwm/replace_point"
require "cwm/common_widgets"
require "installation/widgets/selinux_mode"
require "installation/security_settings"
require "y2security/lsm/config"

Yast.import "HTML"

module Installation
  module Widgets
    # This widget contents a selector for choosing between the supported Linux Security Major
    # Modules during installation.
    #
    # @note the selinux module will show also a selector for choosing the SELinux mode to be used
    #   after the system is booted
    class LSM < CWM::CustomWidget
      attr_accessor :settings

      # Constructor
      #
      # @param settings [Installation::SecuritySettings]
      def initialize(settings)
        super()
        @settings = settings
        self.handle_all_events = true
      end

      # @see CWM::CustomWidget#init
      def init
        lsm_selector_widget.init
        refresh
      end

      # @see CWM::CustomWidget#contents
      def contents
        VBox(
          lsm_selector_widget,
          Left(replace_widget)
        )
      end

      # It refresh the widget content dinamically when the selection of the LSM is modified
      #
      # @param event [Hash] a UI event
      def handle(event)
        return if event["ID"] != lsm_selector_widget.widget_id

        refresh
        nil
      end

    private

      def replace_widget
        @replace_widget ||= CWM::ReplacePoint.new(id: "lsm_widget", widget: empty_lsm_widget)
      end

      def empty_lsm_widget
        @empty_lsm_widget ||= CWM::Empty.new("lsm_empty")
      end

      def lsm_selector_widget
        @lsm_selector_widget ||= LSMSelector.new(settings.lsm_config)
      end

      def selinux_widget
        @selinux_widget ||= SelinuxMode.new(settings.lsm_config.selinux)
      end

      # When the selected LSM is SELinux it shows the widget for selecting the SELinux mode
      def refresh
        case lsm_selector_widget.value
        when "selinux" then replace_widget.replace(selinux_widget)
        else
          replace_widget.replace(empty_lsm_widget)
        end
      end
    end

    # This class is a ComboBox for selecting the desired Linux Security Module to be used after the
    # instalaltion
    class LSMSelector < CWM::ComboBox
      attr_reader :settings

      # Constructor
      #
      # @param settings [Y2Security::LSM::Config]
      def initialize(settings)
        super()
        textdomain "installation"

        @settings = settings
      end

      def init
        self.value = settings.selected&.id.to_s
        disable if items.size <= 1
      end

      def opt
        [:notify, :hstretch]
      end

      def label
        # TRANSLATORS: Linux Security Module Selector label.
        _("Selected Module")
      end

      def items
        available_modules.map { |m| [m.id.to_s, m.label] }
      end

      def store
        settings.select(value)
      end

      def help
        Yast::HTML.Para(
          # TRANSLATORS: Linux Security Module Selector help.
          _("Allows to choose between available major Linux Security Modules like:") +
          Yast::HTML.List(available_modules.map(&:label))
        )
      end

    private

      def available_modules
        settings.selectable
      end
    end
  end
end

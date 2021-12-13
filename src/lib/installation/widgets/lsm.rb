require "yast"
require "cwm/custom_widget"
require "cwm/replace_point"
require "cwm/common_widgets"
require "installation/widgets/selinux_mode"

Yast.import "HTML"

module Installation
  module Widgets
    class LSM < CWM::CustomWidget
      attr_accessor :settings

      def initialize(settings)
        @settings = settings
        self.handle_all_events = true
      end

      def init
        lsm_selector_widget.init
        refresh
      end

      def contents
        VBox(
          lsm_selector_widget,
          Left(replace_widget)
        )
      end

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

      def handle(event)
        return if event["ID"] != lsm_selector_widget.widget_id

        refresh
        nil
      end

    private

      def refresh
        case lsm_selector_widget.value
        when "selinux" then replace_widget.replace(selinux_widget)
        else
          replace_widget.replace(empty_lsm_widget)
        end
      end
    end

    class LSMSelector < CWM::ComboBox
      attr_reader :settings

      def initialize(settings)
        textdomain "installation"

        @settings = settings
      end

      def init
        self.value = settings.selected&.id.to_s
      end

      def opt
        [:notify, :hstretch]
      end

      def label
        # TRANSLATORS: SELinux Mode just SELinux is already content of frame.
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
          _("Allows to choose between available Linux Security major modules like:") +
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

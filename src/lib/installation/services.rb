require "yast"

Yast.import 'SystemdService'

module Installation
  # Represents services manipulation in installation.
  class Services
    class << self
      include Yast::Logger

      def enabled
        @enabled ||= []
        @enabled
      end

      def enabled=(services)
        if !services.is_a?(::Array)
          raise ArgumentError, "Services#enabled= allows only Array as " \
            "argument, not #{services.inspect}"
        end

        @enabled = services
      end

      def write
        enabled.each do |service|
          log.info "Enabling service #{service}"
          s = Yast::SystemdService.find!(service)
          s.enable
        end
      end
    end
  end
end

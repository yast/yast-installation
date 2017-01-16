require "yast"

Yast.import "SystemdService"

module Installation
  # Represents services manipulation in installation.
  #
  # @note For installed system use ServicesManagerServices from
  # yast2-services-manager. But for installation it is not suitable as it
  # expects list of all systemd services in advance and try to adapt all of it.
  # On other hand goal of this module is to do just fine tuning of few single
  # services and keep defaults for rest.
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

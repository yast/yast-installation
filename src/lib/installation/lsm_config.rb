require "yast"
require "y2security/lsm/config"

module Installation
  # This class stores the LSM configuration needed during the installation like selecting the LSM
  # to be used
  class LSMConfig
    include Yast::Logger
    extend Forwardable

    # Constructor
    def initialize
      @config = Y2Security::LSM::Config.new
      @config.supported.each do |lsm_module|
        self.class.send(:define_method, lsm_module.id.to_s.to_sym) do
          lsm_module
        end
      end
    end

    # Select the LSM to be used based in the one defined in the control file using apparmor as
    # fallback in case that no one is selected
    def propose_default
      log.info("The settings are #{product_feature_settings.inspect}")
      selected = product_feature_settings.fetch(:default, "apparmor")

      @config.select(selected)
    end

    def_delegators :@config, :supported, :selected, :select, :selectable

    # Returns whether the LSM is configurable during installation or not based in the control file
    # declaration. It returns false in case it is WSL
    #
    # @return [Boolean] true if LSM is configurable during the installation; false otherwise
    def configurable?
      return false if Yast::Arch.is_wsl

      product_feature_settings[:configurable] || false
    end

    # Returns the needed patterns for the selected LSM or an empty array if no one is selected
    #
    # @return [Array<Sting>]
    def needed_patterns
      return [] unless selected

      selected.needed_patterns
    end

    # Save the configuration of the selected LSM or false in case of no one selected
    #
    # @return [Boolean] whether the configuration was save or not
    def save
      return false unless selected

      selected.save
    end

    # Returns the values for the LSM setting from the product features
    #
    # @return [Hash{Symbol => Object}] e.g., { default: :selinux, selinux: { "selectable" => true }}
    #   a hash holding the LSM options defined in the control file;
    #   an empty object if no settings are defined
    def product_feature_settings
      return @product_feature_settings unless @product_feature_settings.nil?

      settings = Yast::ProductFeatures.GetFeature("globals", "lsm").dup
      settings = {} if settings.empty?
      settings.transform_keys!(&:to_sym)

      @product_feature_settings = settings
    end
  end
end

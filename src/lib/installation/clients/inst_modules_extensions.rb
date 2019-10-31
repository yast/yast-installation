require "yast"
require "y2packager/product"
require "y2packager/resolvable"

Yast.import "GetInstArgs"
Yast.import "Pkg"
Yast.import "WorkflowManager"

module Installation
  module Clients
    # Client that add to installation workflow all extension from modules
    class InstModulesExtensions
      include Yast::Logger

      def run
        return :back if Yast::GetInstArgs.going_back

        Yast::WorkflowManager.merge_modules_extensions(extension_packages)

        :next
      end

    private

      PROVIDES_KEY = "installer_module_extension()".freeze
      PROVIDES_PRODUCT = "extension_for_product()".freeze

      def extension_packages
        product = Y2Packager::Product.selected_base
        extension_packages = Yast::Pkg.PkgQueryProvides(PROVIDES_KEY)
        log.info "module extension packages #{extension_packages.inspect}"
        dependencies = {}

        extension_packages.select! do |list|
          pkg_name = list.first
          dependencies[pkg_name] = Y2Packager::Resolvable.find(kind: :package).first.deps

          product_provides = dependencies[pkg_name].find_all do |d|
            d["provides"] && d["provides"].match(/#{Regexp.escape(PROVIDES_PRODUCT)}/)
          end
          log.info "package #{pkg_name} contains the following product provides #{product_provides}"

          target_product = product_provides.any? do |d|
            d["provides"][/#{Regexp.escape(PROVIDES_PRODUCT)}\s*=\s*(\S+)/, 1] == product.name
          end

          # If no product is specified for the role, it should be available to all products
          product_provides.empty? || target_product
        end

        extension_packages.map do |list|
          pkg_name = list.first
          extension_provide = dependencies[pkg_name].find do |d|
            d["provides"] && d["provides"].match(/#{Regexp.escape(PROVIDES_KEY)}/)
          end

          module_name = extension_provide["provides"][/#{Regexp.escape(PROVIDES_KEY)}\s*=\s*(\S+)/, 1]
          log.info "extension for module #{module_name} in package #{pkg_name}"

          pkg_name
        end
      end
    end
  end
end

require "yast"

Yast.import "GetInstArgs"
Yast.import "Pkg"
Yast.import "WorkflowManager"

module Installation
  module Clients

    class InstModulesExtensions
      include Yast::Logger

      def run
        return :back if Yast::GetInstArgs.going_back

        Yast::WorkflowManager.merge_modules_extensions(extension_packages)

        :next
      end

    private

      def extension_packages
        extension_packages = Yast::Pkg.PkgQueryProvides("installer_module_extension()")
        log.info "module extension packages #{extension_packages.inspect}"

        extension_packages.map do |list|
          pkg_name = list.first
          dependencies = Yast::Pkg.ResolvableDependencies(pkg_name, :package, "").first["deps"]
          extension_provide = dependencies.find do |d|
            d["provides"] && d["provides"].match(/installer_module_extension\(\)/)
          end

          module_name = extension_provide["provides"][/installer_module_extension\(\)\s*=\s*(\S+)/, 1]
          log.info "extension for module #{module_name} in package #{pkg_name}"

          pkg_name
        end
      end
    end
  end
end

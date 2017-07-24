# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "installation/product"

Yast.import "Pkg"

module Installation
  # Read the product information from libzypp
  class ProductReader
    include Yast::Logger

    # In installation Read the available libzypp base products for installation
    # @return [Array<Installation::Product>] the found available base products
    def self.available_base_products
      products = base_products

      installation_mapping = installation_package_mapping
      result = products.map do |p|
        label = p["display_name"] || p["short_name"] || p["name"]
        # TODO: add the display order
        product = Product.new(p["name"], label)
        product.installation_package = installation_mapping[product.name]
        product
      end

      result.reject { |p| !p.installation_package }

      log.info "available base products #{result}"

      result
    end

    def self.base_products
      products = Yast::Pkg.ResolvableProperties("", :product, "").select do |p|
        # during installation/upgrade the product["type"] is not valid yet yet
        # (the base product is determined by /etc/products.d/baseproduct symlink)
        # the base product repository is added as the very first repository
        # during installation, so the base product is from repo ID 0
        p["source"] == 0
      end

      # remove duplicates, there migth be different flavors ("DVD"/"POOL")
      # or archs (x86_64/i586)
      products.uniq! { |p| p["name"] }


      log.info "Found products: #{products.map { |p| p["name"] }}"

      products
    end

    def self.installation_package_mapping
      installation_packages = Yast::Pkg.PkgQueryProvides("system-installation()")

      mapping = {}
      installation_packages.each do |list|
        pkg_name = list.first
        dependencies = Yast::Pkg.ResolvableDependencies(pkg_name, :package, "")
        install_provide = dependencies.find do |d|
          d["provides"] && d["provides"].match?(/system-installation\(\)/)
        end

        product_name = install_provide[/system-installation\(\)\s*=\s*(\S+)/, 1]
        log.info "package #{pkg_name} install product #{product_name}"
        mapping[product_name] = pkg_name
      end

      mapping
    end
  end
end

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
require "installation/product_sorter"

Yast.import "Pkg"

module Installation
  # Read the product information from libzypp
  class ProductReader
    include Yast::Logger

    # In installation Read the available libzypp base products for installation
    # @return [Array<Installation::Product>] the found available base products,
    #   the products are sorted by the 'displayorder' provides value
    def self.available_base_products
      products = available_products

      installation_mapping = installation_package_mapping
      result = products.map do |prod|
        label = prod["display_name"] || prod["short_name"] || prod["name"]
        prod_pkg = product_package(prod["product_package"], prod["source"])

        if prod_pkg
          prod_pkg["deps"].find { |dep| dep["provides"] =~ /\Adisplayorder\(\s*([0-9]+)\s*\)\z/ }
          displayorder = Regexp.last_match[1].to_i if Regexp.last_match
        end

        product = Product.new(prod["name"], label, order: displayorder)
        product.installation_package = installation_mapping[product.name]
        product
      end

      # only installable products
      result.select!(&:installation_package)

      # sort the products
      result.sort!(&::Installation::PRODUCT_SORTER)

      log.info "available base products #{result}"

      result
    end

    def self.product_package(name, repo_id)
      return nil unless name
      Yast::Pkg.ResolvableDependencies(name, :package, "").find do |prod|
        prod["source"] == repo_id
      end
    end

    # read the available products, remove potential duplicates
    # @return [Array<Hash>] pkg-bindings data structure
    def self.available_products
      products = Yast::Pkg.ResolvableProperties("", :product, "")

      # remove duplicates, there migth be different flavors ("DVD"/"POOL")
      # or archs (x86_64/i586), when selecting the product to install later
      # libzypp will select the correct arch automatically
      products.uniq! { |prod| prod["name"] }
      log.info "Found products: #{products.map { |prod| prod["name"] }}"

      products
    end

    private_class_method :available_products

    def self.installation_package_mapping
      installation_packages = Yast::Pkg.PkgQueryProvides("system-installation()")

      mapping = {}
      installation_packages.each do |list|
        pkg_name = list.first
        # There can be more instances of same package in different version. We except that one
        # package provide same product installation. So we just pick the first one.
        dependencies = Yast::Pkg.ResolvableDependencies(pkg_name, :package, "").first["deps"]
        install_provide = dependencies.find do |d|
          d["provides"] && d["provides"].match(/system-installation\(\)/)
        end

        # parse product name from provides. Format of provide is
        # `system-installation() = <product_name>`
        product_name = install_provide["provides"][/system-installation\(\)\s*=\s*(\S+)/, 1]
        log.info "package #{pkg_name} install product #{product_name}"
        mapping[product_name] = pkg_name
      end

      mapping
    end
  end
end

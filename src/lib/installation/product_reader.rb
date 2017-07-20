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
      products = Yast::Pkg.ResolvableProperties("", :product, "").select do |p|
        # during installation/upgrade the product["type"] is not valid yet yet
        # (the base product is determined by /etc/products.d/baseproduct symlink)
        # the base product repository is added as the very first repository
        # during installation, so the base product is from repo ID 0
        p["source"] == 0
      end

      log.debug "Found base products: #{products}"
      log.info "Found base products: #{products.map { |p| p["name"] }}"

      products.map do |p|
        label = p["display_name"] || p["short_name"] || p["name"]
        # TODO: add the display order
        Product.new(p["name"], label)
      end
    end
  end
end

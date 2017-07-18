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
Yast.import "Pkg"

module Installation
  # Simple Libzypp Product wrapper
  class Product

    attr_reader :name, :label, :order

    # @param name [String] name of the product resolvable
    # @param label [String] user visible product label
    # @param order [Integer,nil] the display order
    def initialize(name, label, order: nil)
      @name = name
      @label = label
      @order = order
    end

    # select the product to install
    # @return [Boolean] true if the product has been sucessfully selected
    def select
      Yast::Pkg.ResolvableInstall(name, :product, "")
    end

    # is the product selected to install?
    # @return [Boolean] true if it is selected
    def selected?
      Yast::Pkg.ResolvableProperties(name, :product, "").any? do |res|
        res["status"] == :selected
      end
    end
  end
end

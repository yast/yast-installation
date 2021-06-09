# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "net/http"
require "uri"
require "json"
require "byebug"

module Installation
  # Connect to the Salt API through the REST interface
  class SaltClient
    include Yast::Logger

    attr_reader :uri, :timeout

    # @param host [String]  Host to connect
    # @param port [Integer] Port to connect
    # @param timeout [Integer] Connection timeout
    def initialize(uri, timeout: 600)
      @uri = uri
      @token = nil
    end

    # Log into the API
    #
    # @param user [String] Username
    # @param password [String] Password
    # @return [Boolean] true if logged successfully; false otherwise
    def login(user, password)
      resp = Net::HTTP.post(
        uri + "/login",
        { username: 'salt', password: 'linux', eauth: 'file' }.to_json,
        "Content-Type" => "application/json"
      )
      @token = resp["x-auth-token"]
      !!@token
    end

    # Listen for events and run the block for each one
    def events(&block)
      req = Net::HTTP::Get.new("/events")
      req["X-Auth-Token"] = @token
      req["Accept"]       = "application/json"

      client.request(req) do |response|
        response.read_body do |line|
          next unless line.start_with?("data:")

          begin
          data = JSON.parse(line.sub("data:", ""))
          yield(data)
          rescue JSON::ParseError => e
            log.error(e.inspect)
          end
        end
      end
    end

  private

    def client
      @client ||= Net::HTTP.new(uri.host, uri.port).tap do |c|
        c.read_timeout = timeout
        # TODO: enable ssl if uri.scheme == "https"
      end
    end
  end
end

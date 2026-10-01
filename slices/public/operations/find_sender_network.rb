# frozen_string_literal: true

require "ipaddr"

module Public
  module Operations
    class FindSenderNetwork
      IPV6_PREFIX = 64

      include Deps["operations.find_visitor_address"]

      def call(request)
        address = find_visitor_address.call(request)
        ip = IPAddr.new(address).native
        ip.ipv6? ? ip.mask(IPV6_PREFIX).to_s : ip.to_s
      rescue IPAddr::Error
        address
      end
    end
  end
end

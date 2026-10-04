# frozen_string_literal: true

require "ipaddr"

module Blog
  module ThrottleKey
    IPV6_PREFIX = 64

    module_function

    def call(address)
      ip = IPAddr.new(address).native
      ip.ipv6? ? ip.mask(IPV6_PREFIX).to_s : ip.to_s
    rescue IPAddr::Error
      address
    end
  end
end

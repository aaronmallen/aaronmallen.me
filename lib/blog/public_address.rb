# frozen_string_literal: true

require "ipaddr"
require "socket"

module Blog
  module PublicAddress
    BLOCKED_NAMES = /\A(localhost|.+\.(localhost|local|internal|home\.arpa))\z/
    BLOCKED_RANGES = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
      ::/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 100:0:0:1::/64 2001::/32 2001:2::/48 2001:db8::/32 2002::/16
      3fff::/20 5f00::/16 fc00::/7 fe80::/10 fec0::/10 ff00::/8
    ].map { IPAddr.new(it) }.freeze
    SPECIAL = %i[link_local? loopback? private?].freeze
    TIMEOUT = 5

    class << self
      def addresses(host, timeout: TIMEOUT)
        Addrinfo.getaddrinfo(host, nil, nil, :STREAM, timeout:).map(&:ip_address)
      rescue SocketError
        Blog::Constants::EMPTY_ARRAY
      end

      def allowed?(address)
        ip = IPAddr.new(address).then { it.ipv4_mapped? ? it.native : it }
        SPECIAL.none? { ip.public_send(it) } && refused.none? { it.include?(ip) }
      rescue IPAddr::InvalidAddressError
        false
      end

      def host?(host, timeout: TIMEOUT)
        return false unless name?(host)

        found = addresses(host, timeout:)
        !found.empty? && found.all? { allowed?(it) }
      end

      def name?(host) = !BLOCKED_NAMES.match?(host)

      private

      def network(interface)
        ip = IPAddr.new(interface.addr.ip_address.sub(/%.*\z/, ""))
        interface.netmask&.ip? ? ip.mask(interface.netmask.ip_address) : ip
      end

      def refused = BLOCKED_RANGES + Socket.getifaddrs.select { it.addr&.ip? }.map { network(it) }
    end
  end
end

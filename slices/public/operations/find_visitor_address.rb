# frozen_string_literal: true

require "ipaddr"

module Public
  module Operations
    class FindVisitorAddress
      PREFIX = "HTTP_"
      REMOTE = "REMOTE_ADDR"
      SEPARATOR = ","

      include Deps["settings"]

      def call(request) = proxied(request) || peer(request)

      private

      def header
        named = settings.proxy[:address_header]
        "#{PREFIX}#{named.tr('-', '_').upcase}" if named
      end

      def nearest(value) = value.to_s.split(SEPARATOR).last.to_s.strip

      def peer(request) = request.get_header(REMOTE).to_s

      def proxied(request)
        name = header
        return nil if name.nil? || !trusted?(peer(request))

        found = nearest(request.get_header(name))
        found unless found.empty?
      end

      def trusted?(address)
        peer = IPAddr.new(address).native
        settings.proxy[:trusted_proxies].any? { it.include?(peer) }
      rescue IPAddr::InvalidAddressError
        false
      end
    end
  end
end

# frozen_string_literal: true

require "ipaddr"

module Blog
  module VisitorAddress
    PREFIX = "HTTP_"
    REMOTE = "REMOTE_ADDR"
    SEPARATOR = ","

    module_function

    def call(request) = proxied(request) || peer(request)

    def header
      named = Hanami.app.settings.proxy[:address_header]
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
      Hanami.app.settings.proxy[:trusted_proxies].any? { it.include?(peer) }
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end

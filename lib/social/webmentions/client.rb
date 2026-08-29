# frozen_string_literal: true

require "faraday"
require "ipaddr"
require "socket"
require "timeout"

module Social
  module Webmentions
    class Client
      class Error < StandardError; end
      class Refused < Error; end

      Response = Data.define(:body, :headers, :status, :url)
      Target = Data.define(:address, :uri)

      BLOCKED_RANGES = %w[
        0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
        192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
        ::/128 ::1/128 64:ff9b::/96 2002::/16 fc00::/7 fe80::/10 ff00::/8
      ].map { IPAddr.new(it) }.freeze
      BLOCKED_NAMES = /\A(localhost|.+\.(localhost|local|internal|home\.arpa))\z/
      BUDGET = 15
      ENOUGH = :enough
      MAX_BODY = 1_000_000
      MAX_REDIRECTS = 3
      PORTS = [80, 443].freeze
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze

      def initialize(connection:)
        @connection = connection
      end

      def fetch(url) = within(url) { follow(url) }

      def post(url, **params) = within(url) { request(:post, url, params) }

      private

      attr_reader :connection

      def addresses(host)
        Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)
      rescue SocketError
        Dry::Core::Constants::EMPTY_ARRAY
      end

      def allowed?(address)
        ip = IPAddr.new(address).then { it.ipv4_mapped? ? it.native : it }
        refused.none? { it.include?(ip) }
      rescue IPAddr::InvalidAddressError
        false
      end

      def checked(url, uri, host)
        raise Refused, "#{url} names port #{uri.port}, which is not a web port" unless PORTS.include?(uri.port)

        found = addresses(host)
        raise Error, "#{url} names a host we could not resolve" if found.empty?
        raise Refused, "#{url} resolves to an address we do not reach" unless found.all? { allowed?(it) }

        found.first
      end

      def declared_over?(env) = env.response_headers["content-length"].to_i > MAX_BODY

      def follow(url)
        at = url

        (MAX_REDIRECTS + 1).times do
          response = request(:get, at)
          return response unless redirect?(response)

          at = redirect_url(at, response)
        end

        raise Error, "#{url} redirected more than #{MAX_REDIRECTS} times"
      end

      def location(response) = response.headers["location"].to_s.then { it unless it.empty? }

      def network(interface)
        ip = IPAddr.new(interface.addr.ip_address.sub(/%.*\z/, ""))
        interface.netmask&.ip? ? ip.mask(interface.netmask.ip_address) : ip
      end

      def pin(request, target, on_data)
        request.options.context = { address: target.address }
        request.options.on_data = on_data
      end

      def reachable(url)
        uri = URI.parse(url)
        host = Blog::Types::Normalized::Host.call(url) { Dry::Core::Constants::EMPTY_STRING }
        raise Refused, "#{url} is not an http URL with a host" unless uri.is_a?(URI::HTTP) && !host.empty?
        raise Refused, "#{url} names a host we do not leave the machine for" if BLOCKED_NAMES.match?(host)

        Target.new(address: checked(url, uri, host), uri:)
      rescue URI::InvalidURIError => e
        raise Refused, "#{url} does not parse as a URL: #{e.message}"
      end

      def read(url)
        held = String.new(encoding: Encoding::BINARY)
        env = catch(ENOUGH) { yield(reader(url, held)).env }
        body = held.force_encoding(Encoding::UTF_8).scrub

        Response.new(body:, headers: env.response_headers, status: env.status, url:)
      end

      def reader(url, held)
        lambda do |chunk, _size, env|
          raise Error, "#{url} declares a body over #{MAX_BODY} bytes" if declared_over?(env)

          room = MAX_BODY - held.bytesize
          held << chunk.byteslice(0, room).b
          throw ENOUGH, env if chunk.bytesize >= room
        end
      end

      def redirect?(response) = REDIRECT_STATUSES.include?(response.status) && location(response)

      def redirect_url(from, response)
        URI.join(from, location(response)).to_s
      rescue URI::Error
        raise Error, "#{from} redirected to #{location(response)}, which does not parse as a URL"
      end

      def refused = BLOCKED_RANGES + Socket.getifaddrs.select { it.addr&.ip? }.map { network(it) }

      def request(verb, url, *body)
        target = reachable(url)

        read(url) { |on_data| connection.public_send(verb, target.uri, *body) { pin(it, target, on_data) } }
      rescue Faraday::Error => e
        raise Error, "#{verb.upcase} #{url} failed: #{e.message}"
      end

      def within(url, &)
        Timeout.timeout(BUDGET, &)
      rescue Timeout::Error
        raise Error, "#{url} took longer than #{BUDGET} seconds"
      end
    end
  end
end

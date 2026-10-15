# frozen_string_literal: true

require "faraday"

module Social
  module Webmentions
    class Client
      class Error < Blog::ServiceError; end
      class Refused < Error; end
      class Unreachable < Error; end

      Response = Data.define(:body, :headers, :status, :url)
      Target = Data.define(:address, :uri)

      BUDGET = 15
      ENOUGH = :enough
      MAX_BODY = 1_000_000
      MAX_REDIRECTS = 3
      OK_STATUSES = (200..299)
      PORTS = [80, 443].freeze
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
      RETRY_STATUSES = [429, *500..599].freeze
      UNREACHABLE = [Faraday::ConnectionFailed, Faraday::SSLError, Faraday::TimeoutError].freeze

      def initialize(connection:)
        @connection = connection
      end

      def fetch(url) = follow(url, Deadline.after(BUDGET))

      def post(url, **params) = request(:post, url, Deadline.after(BUDGET), params)

      private

      attr_reader :connection

      def checked(url, uri, host, deadline)
        raise Refused, "#{url} names port #{uri.port}, which is not a web port" unless PORTS.include?(uri.port)

        found = Blog::PublicAddress.addresses(host, timeout: deadline.left)
        raise Unreachable, "#{url} names a host we could not resolve" if found.empty?
        unless found.all? { Blog::PublicAddress.allowed?(it) }
          raise Refused, "#{url} resolves to an address we do not reach"
        end

        found.first
      end

      def declared_over?(env) = env.response_headers["content-length"].to_i > MAX_BODY

      def failure(error, deadline) = deadline.passed? || UNREACHABLE.any? { error.is_a?(it) } ? Unreachable : Error

      def follow(url, deadline)
        at = url

        (MAX_REDIRECTS + 1).times do
          response = request(:get, at, deadline)
          return response unless redirect?(response)

          at = redirect_url(at, response)
        end

        raise Error, "#{url} redirected more than #{MAX_REDIRECTS} times"
      end

      def location(response) = response.headers["location"].to_s.then { it unless it.empty? }

      def overdue(url) = "#{url} took longer than #{BUDGET} seconds"

      def pin(request, target, deadline, on_data)
        request.options.context = { address: target.address, deadline: }
        request.options.on_data = on_data
      end

      def reachable(url, deadline)
        uri = URI.parse(url)
        host = Blog::Types::Normalized::Host.call(url) { Blog::Constants::EMPTY_STRING }
        raise Refused, "#{url} is not an http URL with a host" unless uri.is_a?(URI::HTTP) && !host.empty?
        raise Refused, "#{url} names a host we do not leave the machine for" unless Blog::PublicAddress.name?(host)

        Target.new(address: checked(url, uri, host, deadline), uri:)
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

      def request(verb, url, deadline, *body)
        raise Unreachable, overdue(url) if deadline.passed?

        target = reachable(url, deadline)
        read(url) { |on_data| connection.public_send(verb, target.uri, *body) { pin(it, target, deadline, on_data) } }
      rescue Faraday::Error => e
        raise failure(e, deadline), deadline.passed? ? overdue(url) : "#{verb.upcase} #{url} failed: #{e.message}"
      end
    end
  end
end

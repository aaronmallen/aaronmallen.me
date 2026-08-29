# frozen_string_literal: true

require "rack/session/encryptor"

module Admin
  module Auth
    class SessionReader
      def call(request)
        Session.new(request.env[Rack::RACK_SESSION] || read_cookie(request.cookies[Blog::SessionCookie::KEY]))
      end

      private

      def decrypt(cookie)
        encryptors.each do |encryptor|
          return encryptor.decrypt(cookie)
        rescue Rack::Session::Encryptor::Error, ArgumentError
          next
        end
        nil
      end

      def encryptors
        options = Slice.config.actions.sessions.options.first
        purpose = options.fetch(:key)
        serialize_json = options.fetch(:serialize_json)

        Array(options.fetch(:secrets)).map { Rack::Session::Encryptor.new(it, purpose:, serialize_json:) }
      end

      def read_cookie(cookie)
        data = decrypt(cookie) if cookie.is_a?(String)
        data.is_a?(Hash) ? data.freeze : {}.freeze
      end
    end
  end
end

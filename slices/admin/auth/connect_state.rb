# auto_register: false
# frozen_string_literal: true

require "base64"
require "digest"
require "rack/utils"
require "securerandom"

module Admin
  module Auth
    class ConnectState
      KEY = "service_connects"
      LIFETIME = 10 * 60
      LIMIT = 5

      def initialize(session, now: Time.now)
        @now = now.to_i
        @session = session
      end

      def held?(provider, state) = !find(started, provider, state).nil?

      def start(provider, host: nil)
        state = SecureRandom.urlsafe_base64(32)
        verifier = SecureRandom.urlsafe_base64(48)
        entry = { "at" => @now, "host" => host, "provider" => provider, "state" => state, "verifier" => verifier }
        @session[KEY] = started.push(entry).last(LIMIT)

        { code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false), state: }
      end

      def take(provider, state)
        held = started
        matched = find(held, provider, state)
        return if matched.nil?

        @session[KEY] = held - [matched]
        matched.slice("host", "verifier") if @now - matched["at"].to_i < LIFETIME
      end

      private

      def find(held, provider, state)
        return unless state.is_a?(String)

        held.find { it.is_a?(Hash) && it["provider"] == provider && same?(it["state"], state) }
      end

      def same?(held, given) = held.is_a?(String) && Rack::Utils.secure_compare(held, given)

      def started
        found = @session[KEY]
        found.is_a?(Array) ? found.dup : []
      end
    end
  end
end

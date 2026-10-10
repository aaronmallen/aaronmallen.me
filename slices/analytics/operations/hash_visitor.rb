# frozen_string_literal: true

require "digest"

module Analytics
  module Operations
    class HashVisitor
      DAY = "%Y-%m-%d"
      MONTH = "%Y-%m"
      SEPARATOR = "\n"

      include Deps["settings"]

      def call(address:, user_agent: nil, at: Time.now, period: DAY)
        parts = [settings.analytics_salt, Blog::TimeZone.today(at).strftime(period), address, user_agent].compact

        Digest::SHA256.hexdigest(parts.join(SEPARATOR))
      end

      def throttle_hashes(address, at: Time.now)
        key = Blog::Types::ThrottleKey[address]
        yesterday = Blog::TimeZone.day_start(Blog::TimeZone.today(at) - 1)

        [call(address: key, at:), call(address: key, at: yesterday)]
      end
    end
  end
end

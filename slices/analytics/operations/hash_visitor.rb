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
    end
  end
end

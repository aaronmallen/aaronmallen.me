# frozen_string_literal: true

require "digest"

module Analytics
  module Operations
    class HashVisitor
      SEPARATOR = "\n"

      include Deps["settings"]

      def call(address:, user_agent: nil, at: Time.now)
        parts = [settings.analytics_salt, Blog::TimeZone.today(at).iso8601, address, user_agent].compact

        Digest::SHA256.hexdigest(parts.join(SEPARATOR))
      end
    end
  end
end

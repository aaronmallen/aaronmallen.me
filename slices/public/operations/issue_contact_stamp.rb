# frozen_string_literal: true

require "openssl"

module Public
  module Operations
    class IssueContactStamp
      DIGEST = "SHA256"
      FIELD = :stamp
      MILLISECONDS = 1_000
      PURPOSE = "contact-form"
      SEPARATOR = "--"

      include Deps["settings"]

      def call(at = Time.now)
        issued = (at.to_r * MILLISECONDS).floor
        "#{issued}#{SEPARATOR}#{sign(issued)}"
      end

      private

      def sign(issued) = OpenSSL::HMAC.hexdigest(DIGEST, settings.app_secret, "#{PURPOSE}:#{issued}")
    end
  end
end

# frozen_string_literal: true

require "openssl"

module Public
  class ContactStamp
    DIGEST = "SHA256"
    FIELD = :stamp
    MILLISECONDS = 1_000
    PURPOSE = "contact-form"
    SECONDS_PER_HOUR = 3_600
    SEPARATOR = "--"
    STAMP = /\A(?<issued>\d{1,15})#{SEPARATOR}(?<signature>\h{64})\z/o

    include Deps["settings"]

    def fresh?(stamp, at = Time.now)
      found = STAMP.match(stamp.to_s)
      return false unless found && Rack::Utils.secure_compare(found[:signature], sign(found[:issued]))

      age = at.to_r - Rational(found[:issued].to_i, MILLISECONDS)
      age.between?(minimum, expiry)
    end

    def issue(at = Time.now)
      issued = (at.to_r * MILLISECONDS).floor
      "#{issued}#{SEPARATOR}#{sign(issued)}"
    end

    private

    def expiry = settings.contact[:stamp_expiry_hours] * SECONDS_PER_HOUR

    def minimum = settings.contact[:minimum_submit_seconds]

    def sign(issued) = OpenSSL::HMAC.hexdigest(DIGEST, settings.app_secret, "#{PURPOSE}:#{issued}")
  end
end

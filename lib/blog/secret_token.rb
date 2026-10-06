# frozen_string_literal: true

require "digest"
require "securerandom"

module Blog
  module SecretToken
    BYTES = 32
    SHAPE = /\A[A-Za-z0-9_-]{43}\z/

    module_function

    def digest(value) = Digest::SHA256.hexdigest(value.to_s)

    def generate = SecureRandom.urlsafe_base64(BYTES)
  end
end

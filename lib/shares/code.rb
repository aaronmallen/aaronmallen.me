# frozen_string_literal: true

require "securerandom"

module Shares
  module Code
    ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789".chars.freeze
    ATTEMPTS = 5
    KEY = "short_codes_code_key"
    LENGTH = 5
    SECRET_LENGTH = 16
    TAKEN = "taken"

    def self.random(length = LENGTH) = SecureRandom.alphanumeric(length, chars: ALPHABET)

    def self.secret = random(SECRET_LENGTH)
  end
end

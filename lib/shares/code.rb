# frozen_string_literal: true

require "securerandom"

module Shares
  module Code
    ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789".chars.freeze
    ATTEMPTS = 5
    KEY = "short_codes_code_key"
    LENGTH = 5
    TAKEN = "taken"

    def self.random = SecureRandom.alphanumeric(LENGTH, chars: ALPHABET)
  end
end

# frozen_string_literal: true

require "securerandom"

module Shares
  module Helpers
    module Code
      ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789".chars.freeze
      ATTEMPTS = 5
      KEY = "short_codes_code_key"
      LENGTH = 8
      TAKEN = "taken"
      CONSTRAINTS = { KEY => [:code, TAKEN] }.freeze

      def self.pad(code = nil)
        code = code.to_s
        code + Array.new([LENGTH - code.length, 0].max) { ALPHABET.sample(random: SecureRandom) }.join
      end

      def self.retrying(repo, attempts = ATTEMPTS, &)
        yield
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless repo.violated_constraint(e) == KEY && attempts > 1

        retrying(repo, attempts - 1, &)
      end
    end
  end
end

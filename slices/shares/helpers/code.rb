# frozen_string_literal: true

require "securerandom"

module Shares
  module Helpers
    module Code
      ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789".chars.freeze
      ATTEMPTS = 5
      KEY = "short_codes_code_key"
      MIN_LENGTH = 3
      TAKEN = "taken"
      CONSTRAINTS = { KEY => [:code, TAKEN] }.freeze

      def self.code(index, length)
        Array.new(length) do
          index, digit = index.divmod(ALPHABET.size)
          ALPHABET[digit]
        end.reverse.join
      end

      def self.pick(length, taken)
        values = taken.filter_map { value(it) if it.length == length }.sort
        free = (ALPHABET.size**length) - values.size
        return unless free.positive?

        index = SecureRandom.random_number(free)
        values.each { |value| value <= index ? index += 1 : break }
        code(index, length)
      end

      def self.retrying(repo, attempts = ATTEMPTS, &)
        yield
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless repo.violated_constraint(e) == KEY && attempts > 1

        retrying(repo, attempts - 1, &)
      end

      def self.value(code)
        code.each_char.reduce(0) { |sum, char| (sum * ALPHABET.size) + (ALPHABET.index(char) || (return nil)) }
      end
    end
  end
end

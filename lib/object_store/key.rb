# frozen_string_literal: true

require "securerandom"

module ObjectStore
  module Key
    BYTES = 16

    def self.generate = SecureRandom.hex(BYTES)
  end
end

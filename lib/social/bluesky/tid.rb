# frozen_string_literal: true

module Social
  module Bluesky
    module Tid
      CLOCK_BITS = 10
      CLOCKS = 1 << CLOCK_BITS
      LENGTH = 13
      SLOTS = 1_000_000

      def self.for(id, at)
        micros = (at.to_i * SLOTS) + (id % SLOTS)
        value = (micros << CLOCK_BITS) | ((id / SLOTS) % CLOCKS)

        value.to_s(32).rjust(LENGTH, "0").tr("0-9a-v", "2-7a-z")
      end
    end
  end
end

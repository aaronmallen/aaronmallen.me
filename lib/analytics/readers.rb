# frozen_string_literal: true

module Analytics
  module Readers
    MONTHS = 12

    def self.window_opened_at(at = Time.now) = (at.to_datetime << MONTHS).to_time
  end
end

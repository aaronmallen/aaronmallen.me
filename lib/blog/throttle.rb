# frozen_string_literal: true

module Blog
  class Throttle
    THROTTLED = :throttled

    attr_reader :limit, :total_limit

    def initialize(settings)
      @limit = settings[:throttle_limit]
      @total_limit = settings[:total_throttle_limit]
      @window = settings[:throttle_window_minutes] * Helpers::Figures::MINUTE
    end

    def since(at = Time.now) = at - @window

    def under?(from_visitor, total = nil) = from_visitor < limit && (total.nil? || total < total_limit)
  end
end

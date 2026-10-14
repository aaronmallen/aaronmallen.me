# frozen_string_literal: true

module Blog
  class Timer
    KEY = :blog_timer

    def self.count(time) = Thread.current[KEY]&.count(time)

    def self.start = new(Thread.current[KEY]).tap { Thread.current[KEY] = it }

    def initialize(outer)
      @outer = outer
      @query_count = 0
      @query_time = 0.0
      @started = now
    end

    def count(time)
      @query_count += 1
      @query_time += time
    end

    def stop
      Thread.current[KEY] = @outer

      { duration: now - @started, query_count: @query_count, query_time: @query_time }
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
  end
end

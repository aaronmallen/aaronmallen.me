# frozen_string_literal: true

module Social
  module Webmentions
    Deadline = Data.define(:at) do
      def self.after(seconds) = new(at: now + seconds)

      def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      def left = at - self.class.now

      def passed? = !left.positive?
    end
  end
end

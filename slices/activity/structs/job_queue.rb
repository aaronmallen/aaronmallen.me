# frozen_string_literal: true

module Activity
  module Structs
    JobQueue = Data.define(:name, :size, :latency, :jobs) do
      def self.from(queue, jobs = nil) = new(name: queue.name, size: queue.size, latency: queue.latency, jobs:)
    end
  end
end

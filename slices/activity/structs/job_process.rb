# frozen_string_literal: true

module Activity
  module Structs
    JobProcess = Data.define(:host, :pid, :started_at, :queues, :concurrency, :stopping, :jobs) do
      def self.from(process, works)
        new(
          host: process["hostname"], pid: process["pid"], started_at: Time.at(process["started_at"].to_f),
          queues: process.queues.to_a, concurrency: process["concurrency"].to_i, stopping: process.stopping?,
          jobs: works.map { JobEntry.from(it.job, it.run_at) },
        )
      end

      def stopping? = stopping
    end
  end
end

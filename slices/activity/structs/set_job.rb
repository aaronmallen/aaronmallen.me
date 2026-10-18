# frozen_string_literal: true

require "sidekiq/job_retry"

module Activity
  module Structs
    SetJob = Data.define(
      :set, :jid, :name, :args, :queue, :at, :created_at, :enqueued_at, :failed_at, :retried_at, :error_class,
      :error_message, :retries, :max_retries, :backtrace,
    ) do
      def self.failure(entry)
        {
          error_class: entry["error_class"], error_message: entry["error_message"], retries: entry["retry_count"],
          max_retries: max_retries(entry["retry"]), backtrace: entry.error_backtrace,
        }
      end

      def self.from(set, entry)
        new(
          set:, jid: entry.jid, name: entry.display_class, args: entry.display_args, queue: entry.queue, at: entry.at,
          **stamps(entry), **failure(entry),
        )
      end

      def self.max_retries(retry_option)
        return retry_option if retry_option.is_a?(Integer)

        Sidekiq.default_configuration[:max_retries] || Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS
      end

      def self.stamps(entry)
        {
          created_at: (entry.created_at if entry["created_at"]), enqueued_at: entry.enqueued_at,
          failed_at: entry.failed_at, retried_at: entry.retried_at,
        }
      end

      def arguments = JSON.generate(args)[1...-1]

      def error = [error_class, error_message].compact.join(": ")

      def error? = !error_class.nil?

      def last_failed_at = retried_at || failed_at

      def times
        { created: created_at, enqueued: enqueued_at, failed: failed_at, retried: retried_at, set.to_sym => at }.compact
      end
    end
  end
end

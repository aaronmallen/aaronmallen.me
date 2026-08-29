# frozen_string_literal: true

module Blog
  module Concurrency
    DEFAULT_WEB_THREADS = 5
    WEB_THREADS_VARIABLE = "HANAMI_MAX_THREADS"

    class << self
      def threads = worker? ? worker_threads : web_threads

      def web_threads = Integer(ENV.fetch(WEB_THREADS_VARIABLE, DEFAULT_WEB_THREADS))

      def worker_threads = Sidekiq.default_configuration.total_concurrency

      private

      def worker? = defined?(Sidekiq) && Sidekiq.server?
    end
  end
end

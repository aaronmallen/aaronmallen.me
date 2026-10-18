# frozen_string_literal: true

require "blog/extensions"
require "sidekiq/api"
require "sidekiq/paginator"

module Blog
  module SidekiqQueuePage
    extend Sidekiq::Paginator

    Extensions.pin(
      self,
      gem: "sidekiq",
      version: "8.1.7",
      reason: "it builds Sidekiq::JobRecord through its private constructor and pages through the Web UI's Paginator",
      upstream: nil,
    )

    def self.call(name, number, size)
      page("queue:#{name}", number, size, reverse: true).last.map { Sidekiq::JobRecord.new(it, name) }
    end
  end
end

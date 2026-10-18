# frozen_string_literal: true

require "blog/extensions"
require "sidekiq/api"
require "sidekiq/paginator"

module Blog
  module SidekiqSetPage
    extend Sidekiq::Paginator

    Extensions.pin(
      self,
      gem: "sidekiq",
      version: "8.1.7",
      reason: "it builds Sidekiq::SortedEntry through its private constructor and pages through the Web UI's Paginator",
      upstream: nil,
    )

    def self.call(key, number, size, reverse: false)
      page(key, number, size, reverse:).last.map { |value, score| Sidekiq::SortedEntry.new(nil, score, value) }
    end
  end
end

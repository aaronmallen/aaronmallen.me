# frozen_string_literal: true

require "sidekiq/api"
require "sidekiq/paginator"

module Blog
  module SidekiqSetPage
    extend Sidekiq::Paginator

    def self.call(key, number, size, reverse: false)
      page(key, number, size, reverse:).last.map { |value, score| Sidekiq::SortedEntry.new(nil, score, value) }
    end
  end
end

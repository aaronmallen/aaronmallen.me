# frozen_string_literal: true

require "sidekiq/api"
require "sidekiq/paginator"

module Blog
  module SidekiqQueuePage
    extend Sidekiq::Paginator

    def self.call(name, number, size)
      page("queue:#{name}", number, size, reverse: true).last.map { Sidekiq::JobRecord.new(it, name) }
    end
  end
end

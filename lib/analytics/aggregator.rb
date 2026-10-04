# frozen_string_literal: true

module Analytics
  module Aggregator
    KNOWN = { "feedly" => /\bfeedly\b/i, "inoreader" => /\binoreader\b/i, "newsblur" => /\bnewsblur\b/i }.freeze
    SUBSCRIBERS = /\b(\d{1,9}) subscribers?\b/i

    Count = Data.define(:aggregator, :subscribers)

    def self.parse(user_agent)
      agent = user_agent.to_s
      subscribers = agent[SUBSCRIBERS, 1] or return
      aggregator = KNOWN.find { |_, pattern| pattern.match?(agent) }&.first

      Count.new(aggregator:, subscribers: Integer(subscribers, 10)) if aggregator
    end
  end
end

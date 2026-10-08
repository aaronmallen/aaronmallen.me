# frozen_string_literal: true

module Analytics
  module Operations
    class ParseAggregator
      KNOWN = { "feedly" => /\bfeedly\b/i, "inoreader" => /\binoreader\b/i, "newsblur" => /\bnewsblur\b/i }.freeze
      SUBSCRIBERS = /\b(\d{1,9}) subscribers?\b/i

      def call(user_agent)
        agent = user_agent.to_s
        subscribers = agent[SUBSCRIBERS, 1] or return
        aggregator = KNOWN.find { |_, pattern| pattern.match?(agent) }&.first

        Structs::AggregatorCount.new(aggregator:, subscribers: Integer(subscribers, 10)) if aggregator
      end
    end
  end
end

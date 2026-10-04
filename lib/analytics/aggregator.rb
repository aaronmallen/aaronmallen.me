# frozen_string_literal: true

module Analytics
  module Aggregator
    KNOWN = { "feedly" => /\bfeedly\b/i, "inoreader" => /\binoreader\b/i, "newsblur" => /\bnewsblur\b/i }.freeze
    MAX_NAME = 32
    NAME = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*/
    SUBSCRIBERS = /\b(\d{1,9}) subscribers?\b/i
    WRAPPER = %r{\Amozilla/\S+\s+\((?:compatible;\s*)?}

    Count = Data.define(:aggregator, :subscribers)

    def self.name(agent)
      known = KNOWN.find { |_, pattern| pattern.match?(agent) }&.first
      return known if known

      found = agent.strip.downcase.sub(WRAPPER, "")[NAME]
      found if found && found.length <= MAX_NAME
    end
    private_class_method :name

    def self.parse(user_agent)
      agent = user_agent.to_s
      subscribers = agent[SUBSCRIBERS, 1]
      aggregator = name(agent) if subscribers

      Count.new(aggregator:, subscribers: Integer(subscribers, 10)) if aggregator
    end
  end
end

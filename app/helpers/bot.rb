# frozen_string_literal: true

module Blog
  module Helpers
    module Bot
      KNOWN = Regexp.union(
        %w[
          apis-google archiver axios bot crawl curl embedly facebookexternalhit feedfetcher feedly go-http-client
          httpclient java/ libwww lighthouse mediapartners monitor node-fetch okhttp phantomjs pingdom postman
          preview python-requests ruby scrape slurp spider validator wget yandex
        ],
      )

      def self.match?(user_agent)
        agent = user_agent.to_s.strip
        agent.empty? || KNOWN.match?(agent.downcase)
      end
    end
  end
end

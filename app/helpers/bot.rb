# frozen_string_literal: true

module Blog
  module Helpers
    module Bot
      KNOWN = Regexp.union(
        %w[
          akkoma apis-google archiver axios bot cardyb crawl curl embedly facebookexternalhit feedfetcher feedly
          go-http-client httpclient java/ libwww lighthouse link-check link-title (mastodon/ mediapartners misskey
          monitor node-fetch okhttp phantomjs pingdom pleroma postman preview python-requests ruby scrape slurp
          spider validator webmention wget yandex
        ],
      )

      def self.match?(user_agent)
        agent = user_agent.to_s.strip
        agent.empty? || KNOWN.match?(agent.downcase)
      end
    end
  end
end

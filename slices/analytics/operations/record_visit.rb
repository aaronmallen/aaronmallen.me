# frozen_string_literal: true

module Analytics
  module Operations
    class RecordVisit < Blog::Operation
      BOT = Regexp.union(
        %w[
          apis-google archiver axios bot crawl curl embedly facebookexternalhit feedfetcher feedly go-http-client
          httpclient java/ libwww lighthouse mediapartners monitor node-fetch okhttp phantomjs pingdom postman
          preview python-requests ruby scrape slurp spider validator wget yandex
        ],
      )
      MAX_REFERRER = 2048
      MINUTE = 60
      MAX_READ_SECONDS = 20 * MINUTE
      private_constant :BOT

      include Deps[
        "geo.countries",
        "settings",
        contract: "contracts.visit_contract",
        event_repo: "repos.analytics_event_repo",
        hash_visitor: "operations.hash_visitor",
      ]

      def call(payload, address:, user_agent:, base_url:, signed_in: false)
        visit = step validate(payload)
        return nil if signed_in || bot?(user_agent)

        address_hash = hash_visitor.call(address:)
        step within_limit(address_hash)
        visitor_hash = hash_visitor.call(address:, user_agent:)
        step store(visit, visitor_hash:, address_hash:, address:, base_url:)
      end

      private

      def bot?(user_agent)
        agent = user_agent.to_s.strip
        agent.empty? || BOT.match?(agent.downcase)
      end

      def host(url) = Blog::Types::Normalized::Host.call(url) { nil }

      def read(visit, visitor_hash)
        matched = event_repo.record_read_seconds(
          visitor_hash:,
          view_token: visit[:view_token],
          read_seconds: [visit[:read_seconds], MAX_READ_SECONDS].min,
        )

        matched.zero? ? Failure(:unknown_visit) : Success(matched)
      end

      def referrer_host(referrer, base_url)
        return if referrer.to_s.length > MAX_REFERRER

        found = host(referrer)
        found unless found.nil? || found == host(base_url)
      end

      def store(visit, visitor_hash:, address_hash:, address:, base_url:)
        return read(visit, visitor_hash) if visit[:kind] == Contracts::VisitContract::READ

        view(visit, visitor_hash:, address_hash:, address:, base_url:)
      end

      def title(value)
        found = value.to_s.strip
        found unless found.empty?
      end

      def validate(payload)
        result = contract.call(payload)
        result.success? ? Success(result.to_h) : Failure(:malformed)
      end

      def view(visit, visitor_hash:, address_hash:, address:, base_url:)
        event = event_repo.claim(
          path: visit[:path],
          title: title(visit[:title]),
          visitor_hash:,
          address_hash:,
          referrer_host: referrer_host(visit[:referrer], base_url),
          country_code: countries.code(address),
          view_token: visit[:view_token],
          limit: settings.analytics[:throttle_limit],
          since: window_opened_at,
        )

        event ? Success(event) : Failure(:throttled)
      end

      def window_opened_at
        Time.now - (settings.analytics[:throttle_window_minutes] * MINUTE)
      end

      def within_limit(address_hash)
        stored = event_repo.count_from_address_since(address_hash, window_opened_at)

        stored < settings.analytics[:throttle_limit] ? Success(stored) : Failure(:throttled)
      end
    end
  end
end

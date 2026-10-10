# frozen_string_literal: true

module Analytics
  module Operations
    class RecordVisit < Operation
      BOT = Regexp.union(
        %w[
          apis-google archiver axios bot crawl curl embedly facebookexternalhit feedfetcher feedly go-http-client
          httpclient java/ libwww lighthouse mediapartners monitor node-fetch okhttp phantomjs pingdom postman
          preview python-requests ruby scrape slurp spider validator wget yandex
        ],
      )
      MAX_CLICKS = 50
      MAX_REFERRER = 2048
      MAX_READ_SECONDS = 20 * Blog::Helpers::Figures::MINUTE
      private_constant :BOT

      include Deps[
        "geo.countries",
        "settings",
        check_visit: "operations.check_visit",
        classify_device: "operations.classify_device",
        event_mutations: "repos.analytics_event_mutations",
        event_queries: "repos.analytics_event_queries",
        hash_reader: "operations.hash_reader",
        hash_visitor: "operations.hash_visitor",
        reader_mutations: "repos.post_reader_mutations",
      ]

      def call(payload, address:, user_agent:, base_url:, signed_in: false)
        visit = step check_visit.call(payload)
        return nil if signed_in || bot?(user_agent)

        address_hashes = hash_visitor.throttle_hashes(address)
        step within_limit(address_hashes) unless view?(visit)
        hashes = visitor_hashes(address:, user_agent:)
        step store(visit, hashes:, address_hashes:, address:, user_agent:, base_url:)
      end

      private

      def bot?(user_agent)
        agent = user_agent.to_s.strip
        agent.empty? || BOT.match?(agent.downcase)
      end

      def click(visit, visitor_hashes)
        event_id = event_queries.view_id(visitor_hashes:, view_token: visit[:view_token], path: visit[:path])
        return Failure(:unknown_visit) unless event_id

        clicked = event_mutations.record_click(event_id:, limit: MAX_CLICKS, **visit.slice(:link_host, :link_path))
        clicked ? Success(clicked) : Failure(Blog::Throttle::THROTTLED)
      end

      def click?(visit) = visit[:kind] == Contracts::VisitContract::CLICK

      def host(url) = Blog::Types::Normalized::Host.call(url) { nil }

      def origin(visit, address:, user_agent:, base_url:)
        {
          **referrer(visit[:referrer], base_url),
          **place(address),
          source: Blog::Types::Normalized::RefSource.call(visit[Contracts::VisitContract::REF]) { nil },
          device_class: classify_device.call(user_agent),
        }
      end

      def place(address)
        found = countries.place(address)

        { country_code: found.country, country_name: found.country_name }
      end

      def read(visit, visitor_hashes)
        matched = event_mutations.record_read_seconds(
          visitor_hashes:,
          view_token: visit[:view_token],
          read_seconds: [visit[:read_seconds], MAX_READ_SECONDS].min,
        )

        matched.zero? ? Failure(:unknown_visit) : Success(matched)
      end

      def read?(visit) = visit[:kind] == Contracts::VisitContract::READ

      def record_reader(path, address:, user_agent:)
        reader_mutations.record(path:, reader_hash: hash_reader.call(address:, user_agent:, path:))
      end

      def referrer(url, base_url)
        return {} if url.to_s.length > MAX_REFERRER

        found = host(url)
        return { referrer_host: found } unless found && found == host(base_url)

        { referrer_path: referrer_path(url) }
      end

      def referrer_path(url)
        path = URI.parse(url).path
        path if Contracts::VisitContract::PATH.match?(path)
      rescue URI::InvalidURIError
        nil
      end

      def scroll(visit, visitor_hashes)
        matched = event_mutations.record_scroll_depth(
          visitor_hashes:,
          view_token: visit[:view_token],
          scroll_depth: visit[:scroll_depth],
        )

        matched.zero? ? Failure(:unknown_visit) : Success(matched)
      end

      def scroll?(visit) = visit[:kind] == Contracts::VisitContract::SCROLL

      def store(visit, hashes:, address_hashes:, address:, user_agent:, base_url:)
        return read(visit, view_hashes(hashes, address:, user_agent:)) if read?(visit)
        return scroll(visit, view_hashes(hashes, address:, user_agent:)) if scroll?(visit)
        return click(visit, view_hashes(hashes, address:, user_agent:)) if click?(visit)

        view(visit, hashes:, address_hashes:, address:, user_agent:, base_url:)
      end

      def throttle = Blog::Throttle.new(settings.analytics)

      def title(value)
        found = value.to_s.strip
        found unless found.empty?
      end

      def view(visit, hashes:, address_hashes:, address:, user_agent:, base_url:)
        event = event_mutations.claim(
          path: visit[:path],
          title: title(visit[:title]),
          **hashes,
          address_hashes:,
          **origin(visit, address:, user_agent:, base_url:),
          view_token: visit[:view_token],
          **visit.slice(:scroll_depth),
          limit: throttle.limit,
          since: throttle.since,
        )
        return Failure(Blog::Throttle::THROTTLED) unless event

        record_reader(visit[:path], address:, user_agent:)
        Success(event)
      end

      def view?(visit) = visit[:kind] == Contracts::VisitContract::VIEW

      def view_hashes(hashes, address:, user_agent:)
        yesterday = Blog::TimeZone.day_start(Blog::TimeZone.today - 1)

        [hashes.fetch(:visitor_hash), hash_visitor.call(address:, user_agent:, at: yesterday)]
      end

      def visitor_hashes(address:, user_agent:)
        {
          visitor_hash: hash_visitor.call(address:, user_agent:),
          month_visitor_hash: hash_visitor.call(address:, user_agent:, period: HashVisitor::MONTH),
        }
      end

      def within_limit(address_hashes)
        stored = event_queries.count_from_address_since(address_hashes, throttle.since)

        throttle.under?(stored) ? Success(stored) : Failure(Blog::Throttle::THROTTLED)
      end
    end
  end
end

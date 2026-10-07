# frozen_string_literal: true

require "nokogiri"

module Social
  module Operations
    class SendWebmentions < Operation
      ENDPOINT_SELECTOR = "link[rel~='webmention'], a[rel~='webmention']"
      FAILED = :failed
      HEADER_LINK = /<([^>]*)>([^,]*)/
      LINK_SCHEMES = %w[http https].freeze
      LINK_SELECTOR = "a[href]"
      OK_STATUSES = (200..299)
      PUBLISHED = Blog::Types::PostStatus["published"]
      REJECTED = :rejected
      REL = "webmention"
      REL_PARAM = /rel\s*=\s*(?:"([^"]*)"|'([^']*)'|([^;\s]+))/i
      RETRY_STATUSES = (500..599)
      SENT = :sent
      SKIPPED = :skipped
      private_constant :ENDPOINT_SELECTOR, :HEADER_LINK, :LINK_SCHEMES, :LINK_SELECTOR, :REL, :REL_PARAM

      include Deps[
        "routes",
        "webmentions.client",
        post_queries: "posts.repos.post_queries",
        record_post_webmentions: "posts.operations.record_post_webmentions",
        webmention_queries: "repos.webmention_queries",
      ]

      def call(post_id)
        post = step eligible(post_id)
        source = source_url(post)
        links = links_in(post, source)

        step announce(post, source, links)
      end

      private

      def advertised?(params)
        match = REL_PARAM.match(params)
        match && match.captures.compact.first.to_s.split.include?(REL)
      end

      def announce(post, source, links)
        outcomes = targets_for(post, links).to_h { [it, deliver(source, it)] }
        unsent = outcomes.filter_map { |target, outcome| target if outcome == FAILED }
        record_post_webmentions.call(post.id, targets: links | unsent, unsent:)
        return Failure(:send_failed) if unsent.any?

        Success(outcomes.values.count(SENT))
      end

      def deliver(source, target)
        endpoint = endpoint_for(target)
        return SKIPPED unless endpoint

        outcome(client.post(endpoint, source:, target:).status)
      rescue Webmentions::Client::Refused
        REJECTED
      rescue Webmentions::Client::Error
        FAILED
      end

      def eligible(post_id)
        return Failure(:not_sending) unless webmention_queries.settings.send_on_publish

        post = post_queries.by_id(post_id)
        return Failure(:not_a_post) unless post&.status == PUBLISHED

        Success(post)
      end

      def elsewhere(source, href)
        uri = URI.join(source, href.to_s.strip)
        found = host(uri)
        return nil unless LINK_SCHEMES.include?(uri.scheme) && !found.empty? && found != host(source)

        uri.fragment = nil
        uri.to_s
      rescue URI::Error, ArgumentError
        nil
      end

      def endpoint_for(target)
        response = client.fetch(target)
        return nil unless OK_STATUSES.cover?(response.status)

        endpoint_in_headers(response) || endpoint_in_markup(response)
      rescue Webmentions::Client::Error
        nil
      end

      def endpoint_in_headers(response)
        found = response.headers["link"].to_s.scan(HEADER_LINK).find { |_url, params| advertised?(params) }

        resolve(response, found.first) if found
      end

      def endpoint_in_markup(response)
        Nokogiri::HTML5.parse(response.body.to_s).at_css(ENDPOINT_SELECTOR)&.then { resolve(response, it["href"]) }
      end

      def host(url) = Blog::Types::Normalized::Host.call(url) { Blog::Constants::EMPTY_STRING }

      def links_in(post, source)
        html = ::Posts::Markdown.to_html(post.body)

        Nokogiri::HTML5.parse(html).css(LINK_SELECTOR).filter_map { elsewhere(source, it["href"]) }.uniq
      end

      def outcome(status)
        return SENT if OK_STATUSES.cover?(status)

        RETRY_STATUSES.cover?(status) ? FAILED : REJECTED
      end

      def resolve(response, href)
        URI.join(response.url, href.to_s.strip).to_s
      rescue URI::Error, ArgumentError
        nil
      end

      def source_url(post) = routes.url(:post, slug: post.slug).to_s

      def targets_for(post, links)
        unsent = post.unsent_webmention_targets.to_a
        unsent.empty? ? links | post.webmention_targets.to_a : unsent
      end
    end
  end
end

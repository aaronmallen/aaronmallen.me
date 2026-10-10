# frozen_string_literal: true

module Social
  module Operations
    class ReceiveWebmention < Blog::Operation
      MAX_URL = 2048
      TARGET_PATH = %r{\A#{Hanami.app.settings.writing_path}/(?<slug>[^/]+)\z}

      include Deps[
        "settings",
        honeybadger: "honeybadger.agent",
        post_queries: "posts.repos.post_queries",
        webmention_mutations: "repos.webmention_mutations",
        webmention_queries: "repos.webmention_queries",
      ]

      def call(source:, target:, visitor_hashes:)
        step within_limits(visitor_hashes)
        source_url = step url(source)
        target_url = step url(target)
        step distinct(source_url, target_url)
        step accepted(source_url, webmention_queries.settings)
        post = step post_for(target_url)
        queue(source_url, target_url, post, visitor_hashes)

        post
      end

      private

      def accepted(source_url, webmention_settings)
        return Failure(:bridgy_off) if Webmentions::Source.bridgy?(source_url) && !webmention_settings.accept_bridgy
        return Failure(:not_receiving) unless webmention_settings.receive

        Success(source_url)
      end

      def distinct(source_url, target_url)
        source_url == target_url ? Failure(:same_url) : Success(source_url)
      end

      def post_for(target_url)
        return Failure(:foreign_target) unless settings.owns?(target_url)

        slug = slug_in(target_url)
        post = slug && post_queries.published_by_slug(slug)
        return Failure(:not_a_post) unless post
        return Failure(:webmentions_off) unless post.webmentions_enabled

        Success(post)
      end

      def queue(source_url, target_url, post, visitor_hashes)
        step webmention_mutations.claim_receipt(
          post_id: post.id, source_url: source_url.to_s, visitor_hashes:, since: throttle.since,
          limit: throttle.limit, total_limit: throttle.total_limit,
        )

        verify(post.id, source_url.to_s, target_url.to_s)
      end

      def slug_in(target_url)
        escaped = TARGET_PATH.match(target_url.path)&.[](:slug)
        slug = escaped && ::Rack::Utils.unescape_path(escaped)
        slug if slug&.valid_encoding? && Blog::Types::Slug.valid?(slug)
      end

      def throttle = Blog::Throttle.new(settings.webmentions)

      def url(value)
        uri = URI.parse(Blog::Types::Normalized::Url.call(value.to_s) { return Failure(:invalid_url) })
        fits = uri.to_s.bytesize <= MAX_URL
        fits && Blog::Types::Normalized::Host.call(uri) { nil } ? Success(uri) : Failure(:invalid_url)
      rescue URI::Error
        Failure(:invalid_url)
      end

      def verify(post_id, source_url, target_url)
        Jobs::VerifyWebmention.perform_async(source_url, target_url, post_id)
      rescue RedisClient::Error => e
        honeybadger.notify(e)
        webmention_mutations.hold(post_id:, source_url:, target_url:)
      end

      def within_limits(visitor_hashes)
        since = throttle.since
        under = throttle.under?(
          webmention_queries.count_receipts_from_visitor_since(visitor_hashes, since),
          webmention_queries.count_receipts_since(since),
        )

        under ? Success(visitor_hashes) : Failure(Blog::Throttle::THROTTLED)
      end
    end
  end
end

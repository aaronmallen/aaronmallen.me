# frozen_string_literal: true

module Social
  module Operations
    class ReceiveWebmention < Operation
      MAX_URL = 2048
      TARGET_PATH = %r{\A#{Blog::Site::WRITING}/(?<slug>[^/]+)\z}

      include Deps[
        "settings",
        honeybadger: "honeybadger.agent",
        published_post_by_slug: "posts.queries.published_by_slug",
        webmention_repo: "repos.webmention_repo",
      ]

      def call(source:, target:, visitor_hash:)
        step within_limits(visitor_hash)
        source_url = step url(source)
        target_url = step url(target)
        step distinct(source_url, target_url)
        step accepted(source_url, webmention_repo.settings)
        post = step post_for(target_url)
        queue(source_url, target_url, post, visitor_hash)

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
        post = slug && published_post_by_slug.call(slug)
        return Failure(:not_a_post) unless post
        return Failure(:webmentions_off) unless post.webmentions_enabled

        Success(post)
      end

      def queue(source_url, target_url, post, visitor_hash)
        limits = settings.webmentions
        step webmention_repo.claim_receipt(
          post_id: post.id, source_url: source_url.to_s, visitor_hash:, since: window_opened_at,
          limit: limits[:throttle_limit], total_limit: limits[:total_throttle_limit],
        )

        verify(post.id, source_url.to_s, target_url.to_s)
      end

      def slug_in(target_url)
        escaped = TARGET_PATH.match(target_url.path)&.[](:slug)
        slug = escaped && ::Rack::Utils.unescape_path(escaped)
        slug if slug&.valid_encoding? && Blog::Types::Slug.valid?(slug)
      end

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
        webmention_repo.hold(post_id:, source_url:, target_url:)
      end

      def window_opened_at
        Time.now - (settings.webmentions[:throttle_window_minutes] * Blog::Figures::MINUTE)
      end

      def within_limits(visitor_hash)
        since = window_opened_at
        limits = settings.webmentions
        under = webmention_repo.count_receipts_from_visitor_since(visitor_hash, since) < limits[:throttle_limit] &&
                webmention_repo.count_receipts_since(since) < limits[:total_throttle_limit]

        under ? Success(visitor_hash) : Failure(:throttled)
      end
    end
  end
end

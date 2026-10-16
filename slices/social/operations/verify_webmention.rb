# frozen_string_literal: true

module Social
  module Operations
    class VerifyWebmention < Blog::Operation
      GONE_STATUSES = [404, 410].freeze
      TYPE_TOGGLES = { "like" => :auto_approve_likes, "repost" => :auto_approve_reposts }.freeze

      include Deps[
        client: "page_fetcher.webmention",
        check_author_scope: "operations.check_author_scope",
        post_queries: "posts.repos.post_queries",
        webmention_mutations: "repos.webmention_mutations",
        webmention_queries: "repos.webmention_queries",
      ]

      def call(source:, target:, post_id:)
        settings = webmention_queries.settings
        step accepting(source, settings)
        post = step open_post(post_id)
        response = step fetch(post, source)
        page = Webmentions::Source.new(url: response.url, target:, html: response.body)
        step linking(page, post, source)

        store(page, post, source, settings)
      end

      private

      def accepting(source, settings)
        return Failure(:bridgy_off) if Webmentions::Source.bridgy?(source) && !settings.accept_bridgy
        return Failure(:not_receiving) unless settings.receive

        Success(settings)
      end

      def approved_type?(page, settings) = TYPE_TOGGLES.key?(page.type) && settings.public_send(TYPE_TOGGLES[page.type])

      def fetch(post, source)
        response = client.fetch(source)
        GONE_STATUSES.include?(response.status) ? forget(post, source, :source_gone) : read(response)
      rescue PageFetcher::Client::Refused
        Failure(:source_refused)
      rescue PageFetcher::Client::Unreachable
        Failure(:source_unreachable)
      rescue PageFetcher::Client::Error
        Failure(:fetch_failed)
      end

      def forget(post, source, reason)
        webmention_mutations.delete_by_source(post.id, source)
        Failure(reason)
      end

      def linking(page, post, source)
        page.links_to? ? Success(page) : forget(post, source, :no_link)
      end

      def open_post(post_id)
        post = post_queries.by_id(post_id)
        post&.published? && post.webmentions_enabled ? Success(post) : Failure(:not_a_post)
      end

      def read(response)
        return Failure(:source_unreachable) if PageFetcher::Client::RETRY_STATUSES.include?(response.status)

        PageFetcher::Client::OK_STATUSES.cover?(response.status) ? Success(response) : Failure(:fetch_failed)
      end

      def status(page, source, settings)
        kept = approved_type?(page, settings)
        approved = kept || trusted?(page, source, settings)

        { status: approved ? Repos::WebmentionMutations::APPROVED : Repos::WebmentionQueries::PENDING, keep_approved: kept }
      end

      def store(page, post, source, settings)
        author = page.author
        webmention_mutations.store(
          post_id: post.id, source_url: source, author_name: author[:name], author_url: author[:url],
          type: page.type, excerpt: page.excerpt, received_at: Time.now, **status(page, source, settings),
        )
      end

      def trusted?(page, source, settings)
        author_url = page.author_link
        return false unless settings.auto_approve_known_authors && author_url

        check_author_scope.call(author_url, [source, page.url], single_author_hosts: settings.single_author_hosts) &&
          webmention_queries.trusted_author?(author_url)
      end
    end
  end
end

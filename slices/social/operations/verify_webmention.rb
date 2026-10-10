# frozen_string_literal: true

module Social
  module Operations
    class VerifyWebmention < Blog::Operation
      GONE_STATUSES = [404, 410].freeze
      OK_STATUSES = (200..299)

      include Deps[
        "webmentions.client",
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

      def approved?(page, source, settings)
        author_url = page.author_link
        return false unless settings.auto_approve_known_authors && author_url

        check_author_scope.call(author_url, [source, page.url], single_author_hosts: settings.single_author_hosts) &&
          webmention_queries.known_author?(author_url)
      end

      def fetch(post, source)
        response = client.fetch(source)
        return forget(post, source, :source_gone) if GONE_STATUSES.include?(response.status)
        return Failure(:fetch_failed) unless OK_STATUSES.cover?(response.status)

        Success(response)
      rescue Webmentions::Client::Refused
        Failure(:source_refused)
      rescue Webmentions::Client::Error
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

      def status(page, source, settings)
        approved?(page, source, settings) ? Repos::WebmentionMutations::APPROVED : Repos::WebmentionQueries::PENDING
      end

      def store(page, post, source, settings)
        author = page.author
        webmention_mutations.store(
          post_id: post.id, source_url: source, author_name: author[:name], author_url: author[:url],
          type: page.type, excerpt: page.excerpt, received_at: Time.now, status: status(page, source, settings),
        )
      end
    end
  end
end

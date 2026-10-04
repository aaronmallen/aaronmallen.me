# frozen_string_literal: true

module Social
  module Operations
    class VerifyWebmention < Blog::Operation
      GONE_STATUSES = [404, 410].freeze
      OK_STATUSES = (200..299)
      PUBLISHED = Blog::Types::PostStatus["published"]

      include Deps["webmentions.client", post_by_id: "posts.queries.by_id", webmention_repo: "repos.webmention_repo"]

      def call(source:, target:, post_id:)
        settings = webmention_repo.settings
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

        scope = Webmentions::AuthorScope.new(author_url, single_author_hosts: settings.single_author_hosts)
        [source, page.url].all? { scope.covers?(it) } && webmention_repo.known_author?(author_url)
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
        webmention_repo.delete_by_source(post.id, source)
        Failure(reason)
      end

      def linking(page, post, source)
        page.links_to? ? Success(page) : forget(post, source, :no_link)
      end

      def open_post(post_id)
        post = post_by_id.call(post_id)
        post&.status == PUBLISHED && post.webmentions_enabled ? Success(post) : Failure(:not_a_post)
      end

      def status(page, source, settings)
        approved?(page, source, settings) ? Repos::WebmentionRepo::APPROVED : Repos::WebmentionRepo::PENDING
      end

      def store(page, post, source, settings)
        author = page.author
        webmention_repo.store(
          post_id: post.id, source_url: source, author_name: author[:name], author_url: author[:url],
          type: page.type, excerpt: page.excerpt, received_at: Time.now, status: status(page, source, settings),
        )
      end
    end
  end
end

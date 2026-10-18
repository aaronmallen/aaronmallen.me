# frozen_string_literal: true

module Shares
  module Operations
    class FetchShortLinkTitle
      LIMIT = 200

      include Deps[
        client: "page_fetcher.link_title", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(id)
        link = short_link_queries.find(id)
        return unless link && link.title.nil?

        title = title_of(client.fetch(link.destination))
        short_link_mutations.fill_title(link.id, link.destination, title) if title
      rescue PageFetcher::Client::Error
        nil
      end

      private

      def title_of(response)
        title = PageFetcher::Page.document(response)&.then { PageFetcher::Page.title(it) }
        title && Blog::Helpers::Truncation.fit(title, limit: LIMIT)
      end
    end
  end
end

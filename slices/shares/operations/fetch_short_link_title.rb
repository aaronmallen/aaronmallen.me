# frozen_string_literal: true

require "nokogiri"

module Shares
  module Operations
    class FetchShortLinkTitle
      HTML = "html"
      LIMIT = 200
      OG_TITLE = "meta[property='og:title']"

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

      def html?(response)
        PageFetcher::Client::OK_STATUSES.include?(response.status) &&
          response.headers["content-type"].to_s.include?(HTML)
      end

      def squish(text) = Blog::Helpers::Whitespace.squish(text.to_s.gsub(/[[:cntrl:]]/, " "))

      def title_of(response)
        return unless html?(response)

        document = Nokogiri::HTML5.parse(response.body)
        title = [document.at_css(OG_TITLE)&.[]("content"), document.at_css("title")&.text]
                .lazy.map { squish(it) }.find { !it.empty? }
        title && Blog::Helpers::Truncation.fit(title, limit: LIMIT)
      end
    end
  end
end

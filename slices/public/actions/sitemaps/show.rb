# frozen_string_literal: true

require "builder"

module Public
  module Actions
    module Sitemaps
      class Show < Action
        NAMESPACE = "http://www.sitemaps.org/schemas/sitemap/0.9"
        PAGES = %i[root about projects contact writing].freeze

        include Deps[post_queries: "posts.repos.post_queries"]

        config.formats.clear.accept :xml
        answer_any_accept :xml

        share_with_caches

        def handle(_request, response)
          posts = post_queries.published
          edited_at = post_queries.edited_at(posts.map(&:id))

          response.body = render(pages + post_entries(posts, edited_at) + tag_pages(posts))
        end

        private

        def pages = PAGES.map { [routes.url(it)] }

        def post_entries(posts, edited_at)
          posts.map { [routes.url(:post, slug: it.slug), [it.changed_at, edited_at[it.id]].compact.max] }
        end

        def render(entries)
          xml = Builder::XmlMarkup.new(indent: 2)
          xml.instruct!(:xml, version: "1.0", encoding: "UTF-8")
          xml.urlset(xmlns: NAMESPACE) do
            entries.each do |loc, lastmod|
              xml.url do
                xml.loc(loc.to_s)
                xml.lastmod(lastmod.utc.iso8601) if lastmod
              end
            end
          end
        end

        def tag_pages(posts) = posts.flat_map { it.tags.map(&:name) }.uniq.sort.map { [routes.url(:tag, tag: it)] }
      end
    end
  end
end

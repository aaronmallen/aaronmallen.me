# frozen_string_literal: true

require "builder"

module Public
  module Operations
    class RenderAtomFeed
      HTML_TYPE = "text/html"
      LANGUAGE = "en"
      MEDIA_TYPE = "application/atom+xml"
      NAMESPACE = "http://www.w3.org/2005/Atom"

      include Deps["routes", "settings"]

      def call(posts, title:, url:, feed_url:)
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!(:xml, version: "1.0", encoding: "UTF-8")
        xml.feed(xmlns: NAMESPACE, "xml:lang": LANGUAGE) do
          feed_head(xml, posts, title:, url:, feed_url:)
          posts.each { entry(xml, it) }
        end
      end

      private

      def entry(xml, post)
        url = routes.url(:post, slug: post.slug).to_s

        xml.entry do
          xml.id(url)
          xml.title(post.title)
          xml.link(rel: "alternate", type: HTML_TYPE, href: url)
          entry_dates(xml, post)
          post.tags.each { xml.category(term: it.name) }
          entry_body(xml, post)
        end
      end

      def entry_body(xml, post)
        summary = post.summary
        xml.summary(summary) if summary
        xml.content(::Posts::Markdown.to_html(post.body), type: "html")
      end

      def entry_dates(xml, post)
        xml.published(timestamp(post.published_at))
        xml.updated(timestamp(post.changed_at))
      end

      def feed_head(xml, posts, title:, url:, feed_url:)
        xml.id(url)
        xml.title(title)
        xml.updated(timestamp(posts.map(&:changed_at).max || Time.now))
        xml.link(rel: "alternate", type: HTML_TYPE, href: url)
        xml.link(rel: "self", type: MEDIA_TYPE, href: feed_url)
        xml.author { xml.name(settings.owner[:name]) }
      end

      def timestamp(time) = time.utc.iso8601
    end
  end
end

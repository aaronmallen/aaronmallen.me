# frozen_string_literal: true

module Posts
  module Operations
    class ComposeAnnouncement
      include Deps["routes"]

      SEPARATOR = "\n\n"

      def call(post) = compose(body: post.syndication_body, slug: post.slug, title: post.title)

      def compose(body:, slug:, title:)
        given = Blog::Types::Text[body]

        given.strip.empty? ? default(slug:, title:) : given
      end

      def default(slug:, title:)
        named = Blog::Types::Text[title].strip

        named.empty? ? Blog::Constants::EMPTY_STRING : "#{named}#{SEPARATOR}#{url(slug)}"
      end

      def url(slug) = routes.url(:post, slug:).to_s
    end
  end
end

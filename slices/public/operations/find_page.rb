# frozen_string_literal: true

module Public
  module Operations
    class FindPage
      FIRST = Blog::Page.new(number: 1, size: 1)

      include Deps[
        public_projects_by_tag: "projects.queries.public_by_tag",
        published_page_by_tag: "posts.queries.published_page_by_tag",
        published_post_by_slug: "posts.queries.published_by_slug",
      ]

      def call(params)
        return post?(unescape(params[:slug])) if params.key?(:slug)
        return tag?(unescape(params[:tag])) if params.key?(:tag)

        true
      end

      private

      def post?(slug) = Blog::Types::Slug.valid?(slug) && !published_post_by_slug.call(slug).nil?

      def tag?(tag)
        return false unless tag == Blog::Types::Normalized::Tag.call(tag) { nil }

        published_page_by_tag.call(tag, FIRST).rows.any? || public_projects_by_tag.call(tag).any?
      end

      def unescape(value) = ::Rack::Utils.unescape_path(value.to_s)
    end
  end
end

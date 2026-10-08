# frozen_string_literal: true

module Admin
  module Operations
    class PreviewAnnouncement
      include Deps[announcement: "posts.operations.compose_announcement"]

      def call(values)
        title = Blog::Types::Text[values[:title]]

        announcement.default(title:, slug: ::Posts::Helpers::PostSlug.derive(slug: values[:slug], title:))
      end
    end
  end
end

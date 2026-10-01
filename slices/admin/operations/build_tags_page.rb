# frozen_string_literal: true

module Admin
  module Operations
    class BuildTagsPage
      NO_ERRORS = Blog::Constants::EMPTY_HASH

      include Deps[
        "settings",
        matching_tags: "tags.queries.matching",
        matching_tag_count: "tags.queries.matching_count",
        tag_usage: "tags.queries.usage",
      ]

      def call(scope:, page: first_page, errors: NO_ERRORS, editing: nil, params: nil, query: nil)
        text = Blog::Types::TrimmedText[query].downcase

        {
          count: matching_tag_count.call(scope:, text:),
          editing:,
          errors:,
          name: name(params),
          query: text,
          scope:,
          tags: matching_tags.call(scope:, text:, page:),
          usage: tag_usage.call(scope:),
        }
      end

      private

      def first_page = Blog::Page.new(number: 1, size: settings.page_size[:admin])

      def name(params) = Blog::Types::Text[Blog::Types::Fields[params][:name]]
    end
  end
end

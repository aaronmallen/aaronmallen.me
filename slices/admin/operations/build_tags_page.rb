# frozen_string_literal: true

module Admin
  module Operations
    class BuildTagsPage
      NO_ERRORS = Blog::Constants::EMPTY_HASH

      include Deps["settings", tag_queries: "tags.repos.tag_queries"]

      def call(scope:, page: first_page, errors: NO_ERRORS, editing: nil, params: nil, query: nil)
        text = Blog::Types::TrimmedText[query].downcase

        {
          count: tag_queries.count_matching(scope, text),
          editing:,
          errors:,
          name: name(params),
          query: text,
          scope:,
          tags: tag_queries.page_matching(scope, text, page),
          usage: tag_queries.usage(scope:),
        }
      end

      private

      def first_page = Blog::Page.new(number: 1, size: settings.page_size[:admin])

      def name(params) = Blog::Types::Text[Blog::Types::Fields[params][:name]]
    end
  end
end

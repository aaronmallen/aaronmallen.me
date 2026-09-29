# frozen_string_literal: true

module Admin
  module Operations
    class BuildTagsPage
      include Deps[all_tags: "tags.queries.all", tag_usage: "tags.queries.usage"]

      def call(scope:, errors: Dry::Core::Constants::EMPTY_HASH, editing: nil, params: nil, query: nil)
        text = Blog::Types::TrimmedText[query].downcase

        {
          editing:,
          errors:,
          name: name(params),
          query: text,
          scope:,
          tags: matching(scope, text),
          usage: tag_usage.call(scope:),
        }
      end

      private

      def matching(scope, text)
        found = all_tags.call(scope:)

        text.empty? ? found : found.select { it.name.include?(text) }
      end

      def name(params) = Blog::Types::Text[Blog::Types::Fields[params][:name]]
    end
  end
end

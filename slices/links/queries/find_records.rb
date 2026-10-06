# frozen_string_literal: true

module Links
  module Queries
    class FindRecords
      LIMIT = 5

      include Deps[records: "queries.linkable_records"]

      def call(text, limit: LIMIT)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_HASH if query.empty?

        Blog::Types::RecordKind.values.to_h { [it, records.matching(it, query, limit:)] }.reject { _2.empty? }
      end
    end
  end
end

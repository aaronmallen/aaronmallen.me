# frozen_string_literal: true

module Links
  module Queries
    class RecordLinks
      include Deps[records: "queries.linkable_records", record_link_repo: "repos.record_link_repo"]

      def call(kind, id)
        id = Blog::Types::IdParam[id]
        return Blog::Constants::EMPTY_HASH unless id && Blog::Types::RecordKind.valid?(kind)

        ids = record_link_repo.partners(kind, id).group_by(&:first).transform_values { it.map(&:last) }

        Blog::Types::RecordKind.values.filter_map { [it, records.named(it, ids[it])] if ids.key?(it) }.to_h
      end
    end
  end
end

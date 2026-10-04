# frozen_string_literal: true

module Analytics
  module Queries
    class ReadThroughsBetween
      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(from:, to:)
        counts = rollup_repo.read_throughs(from:, to:)
        unrolled_summaries.call(from:, to:).each { add(counts, it.read_throughs) }

        counts.reject { |_path, count| count.zero? }
      end

      private

      def add(counts, found) = counts.merge!(found) { |_path, held, more| held + more }
    end
  end
end

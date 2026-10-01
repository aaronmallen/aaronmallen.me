# frozen_string_literal: true

module Analytics
  module Queries
    class SourcesBetween
      FIGURES = %i[views visitors].freeze

      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(from:, to:, path: nil)
        rolled = rollup_repo.sources(from:, to:, path:).map(&:to_h)
        live = unrolled_summaries.call(from:, to:).flat_map(&:sources).select { it.fetch(:path) == path }

        combined(rolled + live).sort_by { [-it.fetch(:visitors), -it.fetch(:views), it.fetch(:source)] }
      end

      private

      def combined(rows)
        rows.group_by { it.fetch(:source) }.map do |source, found|
          { source:, **FIGURES.to_h { |key| [key, found.sum { it.fetch(key) }] } }
        end
      end
    end
  end
end

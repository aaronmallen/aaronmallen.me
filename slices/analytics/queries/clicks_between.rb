# frozen_string_literal: true

module Analytics
  module Queries
    class ClicksBetween
      LINK = %i[link_host link_path].freeze

      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(path:, from:, to:)
        rolled = rollup_repo.clicks(path:, from:, to:).map(&:to_h)
        live = unrolled_summaries.call(from:, to:).flat_map(&:clicks).select { it.fetch(:path) == path }

        combined(rolled + live).sort_by { [-it.fetch(:clicks), *it.values_at(*LINK)] }
      end

      private

      def combined(rows)
        rows.group_by { it.values_at(*LINK) }.map do |(link_host, link_path), found|
          { link_host:, link_path:, clicks: found.sum { it.fetch(:clicks) } }
        end
      end
    end
  end
end

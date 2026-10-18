# frozen_string_literal: true

module Performance
  module Operations
    class PruneTiming
      include Deps[mutations: "repos.rollup_mutations"]

      def call
        days = Repos::TimingReportQueries::RETENTION_DAYS

        mutations.prune_before(Blog::TimeZone.day_start(Blog::TimeZone.today - (days - 1)))
      end
    end
  end
end

# frozen_string_literal: true

module Performance
  module Operations
    class PruneTiming
      RETENTION_DAYS = 30

      include Deps[mutations: "repos.rollup_mutations"]

      def call
        mutations.prune_before(Blog::TimeZone.day_start(Blog::TimeZone.today - (RETENTION_DAYS - 1)))
      end
    end
  end
end

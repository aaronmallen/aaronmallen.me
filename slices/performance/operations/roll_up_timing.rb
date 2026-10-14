# frozen_string_literal: true

module Performance
  module Operations
    class RollUpTiming
      include Deps[mutations: "repos.rollup_mutations", queries: "repos.rollup_queries"]

      def call
        yesterday = Blog::TimeZone.today - 1
        first = [queries.newest_day&.next_day, queries.oldest_day].compact.max || yesterday

        ([first, yesterday].min..yesterday).each { mutations.store(it) }
      end
    end
  end
end

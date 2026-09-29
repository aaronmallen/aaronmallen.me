# frozen_string_literal: true

module Activity
  module Queries
    class ActivityDayCount
      include Deps[activity_repo: "repos.activity_repo"]

      def call(from:, to:, **filters) = activity_repo.day_count(from:, to:, **filters)
    end
  end
end

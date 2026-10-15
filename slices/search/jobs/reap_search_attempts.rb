# frozen_string_literal: true

module Search
  module Jobs
    class ReapSearchAttempts < Blog::ScheduledJob
      include Deps[reap_search_attempts: "operations.reap_search_attempts"]

      def perform = reap_search_attempts.call
    end
  end
end

# frozen_string_literal: true

module Performance
  module Repos
    class TimingMutations < Blog::DB::Repo
      def record_job(**row) = performance_jobs.insert(row)

      def record_request(**row) = performance_requests.insert(row)
    end
  end
end

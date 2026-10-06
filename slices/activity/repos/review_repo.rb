# frozen_string_literal: true

module Activity
  module Repos
    class ReviewRepo < Blog::DB::Repo
      RECORDS = %w[post social journal].map { Blog::Types::ActivityKind[it] }.freeze

      def carried(from:, to:) = review_carries.per_task_between(from, to).to_a

      def commits(from:, to:)
        activities.between(from, to).commit_totals_by_repo.to_a.to_h { [it.repo, it.to_h.except(:repo)] }
      end

      def decisions(from:, to:) = review_decisions.closed_between(from, to).to_a.reverse.uniq(&:decision_id).reverse

      def done(from:, to:, **credits) = review_tasks.done_between(from, to).credited(**credits).to_a

      def records(from:, to:) = activities.between(from, to).with_types(RECORDS).oldest_first.to_a

      def seconds_by_day(from:, to:)
        work_session_days.seconds_by_day(from, to).to_a.to_h { [it.worked_on, it.seconds] }
      end
    end
  end
end

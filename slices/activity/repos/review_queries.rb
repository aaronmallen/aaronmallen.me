# frozen_string_literal: true

module Activity
  module Repos
    class ReviewQueries < DB::Repo
      JOURNAL = Blog::Types::ActivityKind["journal"]
      NONE = Blog::Constants::EMPTY_ARRAY
      POST = Blog::Types::ActivityKind["post"]
      SOCIAL = Blog::Types::ActivityKind["social"]
      RECORDS = [POST, SOCIAL, JOURNAL].freeze

      include Deps[review_range: "contracts.review_range_contract"]

      def review(period:, on: Blog::TimeZone.today, credits: Blog::Constants::EMPTY_HASH)
        review_range.call(period:, on:).to_h => { from:, to: }

        Structs::Review.new(
          period:, from:, to:, **tasks(from, to, credits), **records(from, to),
          commits: commits(from, to), decisions: decisions(from, to), worked: worked(from, to),
        )
      end

      private

      def commits(from, to)
        activities.between(from, to).commit_totals_by_repo.to_a.to_h { [it.repo, it.to_h.except(:repo)] }
      end

      def decisions(from, to) = review_decisions.closed_between(from, to).to_a.reverse.uniq(&:decision_id).reverse

      def records(from, to)
        found = activities.between(from, to).with_types(RECORDS).oldest_first.to_a.group_by(&:type)

        {
          posts: found.fetch(POST, NONE),
          social_posts: found.fetch(SOCIAL, NONE),
          journal: Structs::ReviewJournal.from(found.fetch(JOURNAL, NONE)),
        }
      end

      def tasks(from, to, credits)
        {
          done: review_tasks.done_between(from, to).credited(**credits).to_a.group_by(&:closed_on),
          carried: review_carries.per_task_between(from, to).to_a,
        }
      end

      def worked(from, to)
        seconds = work_session_days.seconds_by_day(from, to).to_a.to_h { [it.worked_on, it.seconds] }

        (from..to).to_h { [it, seconds.fetch(it, 0)] }
      end
    end
  end
end

# frozen_string_literal: true

module Activity
  module Repos
    class ReviewQueries < DB::Repo
      JOURNAL = Blog::Types::ActivityKind["journal"]
      NONE = Blog::Constants::EMPTY_ARRAY
      POST = Blog::Types::ActivityKind["post"]
      SOCIAL = Blog::Types::ActivityKind["social"]
      RECORDS = [POST, SOCIAL, JOURNAL].freeze
      TOTALS = %i[commits additions deletions].freeze

      include Deps[review_range: "contracts.review_range_contract"]

      def review(period:, on: Blog::TimeZone.today, focus: nil, credits: Blog::Constants::EMPTY_HASH)
        review_range.call(period:, on:).to_h => { from:, to: }
        focus = nil unless (from..to).cover?(focus)
        shown = focus ? focus..focus : from..to
        found = sections(from, to, credits)

        Structs::Review.new(
          period:, from:, to:, focus:, carried: review_carries.per_task_between(from, to).to_a,
          days: days(from..to, found), **scoped(shown, found),
        )
      end

      private

      def commits(rows) = rows.group_by(&:repo).transform_values { |repo| TOTALS.to_h { [it, repo.sum(&it)] } }

      def days(range, found)
        commits = found[:commits].group_by(&:occurred_on)
        journal = found[:records].fetch(JOURNAL, NONE).group_by(&:occurred_on)

        range.to_h do |day|
          [day, {
            done: found[:done].fetch(day, NONE).size, commits: commits.fetch(day, NONE).sum(&:commits),
            worked_seconds: found[:worked].fetch(day), journal: journal.fetch(day, NONE).size,
          }]
        end
      end

      def done(from, to, credits) = review_tasks.done_between(from, to).credited(**credits).to_a.group_by(&:closed_on)

      def published(found)
        {
          posts: found.fetch(POST, NONE),
          social_posts: found.fetch(SOCIAL, NONE),
          journal: Structs::ReviewJournal.from(found.fetch(JOURNAL, NONE)),
        }
      end

      def scoped(shown, found)
        {
          **found.slice(:done, :worked).transform_values { it.slice(*shown) },
          **published(found[:records].transform_values { within(it, shown, :occurred_on) }),
          commits: commits(within(found[:commits], shown, :occurred_on)),
          decisions: within(found[:decisions], shown, :closed_on).reverse.uniq(&:decision_id).reverse,
        }
      end

      def sections(from, to, credits)
        between = activities.between(from, to)

        {
          done: done(from, to, credits),
          commits: between.commit_totals_by_repo_and_day.to_a,
          decisions: review_decisions.closed_between(from, to).to_a,
          records: between.with_types(RECORDS).oldest_first.to_a.group_by(&:type),
          worked: worked(from, to),
        }
      end

      def within(rows, shown, day) = rows.select { shown.cover?(it.public_send(day)) }

      def worked(from, to)
        seconds = work_session_days.seconds_by_day(from, to).to_a.to_h { [it.worked_on, it.seconds] }

        (from..to).to_h { [it, seconds.fetch(it, 0)] }
      end
    end
  end
end
